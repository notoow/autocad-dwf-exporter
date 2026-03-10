;;; ============================================================
;;; export_dwf_main.lsp  v5
;;;
;;; 기능: 모델 공간의 블록참조(INSERT) 또는 폴리라인 테두리를
;;;       감지하여 각각 DXF, PDF 또는 DWF 로 일괄 내보내기
;;;
;;; 지원: AutoCAD 2015 ~ 2025 (R19 ~ R25), 한/영 모두 동작
;;;
;;; 파일 구성 (같은 폴더에 위치):
;;;   - export_dwf_main.lsp  (이 파일)
;;;   - export_dwf_ui.dcl    (다이얼로그)
;;;
;;; 사용법: APPLOAD → export_dwf_main.lsp → 명령: EXPORT-SMART
;;;
;;; 플롯/내보내기 엔진 (버전 자동 선택):
;;;   R21+(2016~): PDF/DWF는 ActiveX PlotToFile  → 실패 시 -PLOT 자동 폴백
;;;   R20-(2015) : PDF/DWF는 -PLOT 명령 / DXF는 WBLOCK + SaveAs
;;; ============================================================

(vl-load-com)

;;; ============================================================
;;; 섹션 1: 설정 관리
;;; ============================================================

(setq *edwf:cfg* nil)
(setq *edwf:paper-cache* nil)

(defun edwf:init (doc / fp)
  (setq fp (vla-get-fullname doc))
  (setq *edwf:paper-cache* nil)
  (setq *edwf:cfg*
    (list
      (cons "mode"       "sample")
      (cons "layer"      "")
      (cons "aci"        0)
      (cons "format"     "DXF")
      (cons "plotter"    "")
      (cons "ext"        ".dxf")
      (cons "folder"     (if (and fp (/= fp ""))
                           (vl-filename-directory fp)
                           "C:\\Temp"))
      (cons "prefix"     "도면")
      (cons "paper"      "AUTO")
      (cons "ctb"        "none")
      (cons "crop-mode"  "border")
      (cons "minsize"    500)
      (cons "sample-lyr" nil)
      (cons "sample-aci" nil))))

(defun edwf:g (k)   (cdr (assoc k *edwf:cfg*)))
(defun edwf:s (k v / p)
  (setq p (assoc k *edwf:cfg*))
  (if p
    (setq *edwf:cfg* (subst (cons k v) p *edwf:cfg*))
    (setq *edwf:cfg* (cons  (cons k v)   *edwf:cfg*))))

(defun edwf:trim (s)
  (vl-string-trim " " (if s s "")))

(defun edwf:auto-paper-p (paper / s)
  (setq s (strcase (edwf:trim paper)))
  (or (= s "") (= s "AUTO") (= s "자동")))

(defun edwf:none-ctb-p (ctb / s)
  (setq s (strcase (edwf:trim ctb)))
  (or (= s "") (= s "NONE") (= s "없음")))

(defun edwf:paper-display (paper)
  (if (edwf:auto-paper-p paper) "자동" paper))

(defun edwf:ctb-display (ctb)
  (if (edwf:none-ctb-p ctb) "none" ctb))

(defun edwf:effective-ctb ()
  (if (edwf:none-ctb-p (edwf:g "ctb")) "" (edwf:g "ctb")))

(defun edwf:index-ci (item lst / idx found)
  (setq item (strcase item)
        idx  0)
  (while (and lst (null found))
    (if (= item (strcase (car lst)))
      (setq found idx)
      (setq idx (1+ idx)
            lst (cdr lst))))
  found)

(defun edwf:last-string-search (pat str / pos next start)
  (setq start 0)
  (while (setq next (vl-string-search pat str start))
    (setq pos   next
          start (1+ next)))
  pos)

(defun edwf:extract-numbers (str / i ch token nums)
  (setq i 1
        token ""
        nums nil)
  (while (<= i (strlen str))
    (setq ch (substr str i 1))
    (if (wcmatch ch "[0-9.]")
      (setq token (strcat token ch))
      (if (/= token "")
        (setq nums  (append nums (list token))
              token "")))
    (setq i (1+ i)))
  (if (/= token "")
    (setq nums (append nums (list token))))
  nums)

(defun edwf:insunits-mm-factor (/ u)
  (setq u (getvar "INSUNITS"))
  (cond
    ((or (= u 0) (= u 4)) 1.0)
    ((= u 1) 25.4)
    ((= u 2) 304.8)
    ((= u 5) 10.0)
    ((= u 6) 1000.0)
    ((= u 14) 100.0)
    (T 1.0)))

(defun edwf:window-size-mm (pt-min pt-max / factor)
  (setq factor (edwf:insunits-mm-factor))
  (list
    (* factor (abs (- (car  pt-max) (car  pt-min))))
    (* factor (abs (- (cadr pt-max) (cadr pt-min))))))

(defun edwf:paper-dims-mm (paper / upper lp rp chunk nums scale)
  (setq upper (strcase paper)
        lp    (edwf:last-string-search "(" upper)
        rp    (edwf:last-string-search ")" upper))
  (setq chunk
    (if (and lp rp (> rp lp))
      (substr upper (+ lp 2) (- rp lp 1))
      upper))
  (setq nums (edwf:extract-numbers chunk)
        scale
          (cond
            ((wcmatch chunk "*INCH*") 25.4)
            ((wcmatch chunk "*CM*")   10.0)
            ((wcmatch chunk "*MM*")    1.0)
            (T                         1.0)))
  (if (>= (length nums) 2)
    (list
      (* (atof (nth 0 nums)) scale)
      (* (atof (nth 1 nums)) scale))))

(defun edwf:paper-fit-score (paper-w paper-h target-w target-h / fit1 fit2)
  (setq fit1
    (if (and (>= paper-w target-w) (>= paper-h target-h))
      (max (/ paper-w target-w) (/ paper-h target-h))))
  (setq fit2
    (if (and (>= paper-w target-h) (>= paper-h target-w))
      (max (/ paper-w target-h) (/ paper-h target-w))))
  (cond
    ((and fit1 fit2) (min fit1 fit2))
    (fit1 fit1)
    (fit2 fit2)
    (T nil)))

(defun edwf:paper-distance-score (paper-w paper-h target-w target-h)
  (min
    (+ (abs (- paper-w target-w)) (abs (- paper-h target-h)))
    (+ (abs (- paper-w target-h)) (abs (- paper-h target-w)))))

(defun edwf:get-papers-cached (plotter layout / key hit papers)
  (setq key (strcase plotter)
        hit (assoc key *edwf:paper-cache*))
  (if hit
    (cdr hit)
    (progn
      (setq papers (edwf:get-papers plotter layout))
      (setq *edwf:paper-cache* (cons (cons key papers) *edwf:paper-cache*))
      papers)))

(defun edwf:merge-ci-lists (lst1 lst2 / merged)
  (setq merged nil)
  (foreach item (append lst1 lst2)
    (if (null (edwf:index-ci item merged))
      (setq merged (cons item merged))))
  (if merged
    (vl-sort merged '<)
    nil))

(defun edwf:make-target (name engine plotter ext)
  (list name engine plotter ext))

(defun edwf:target-name (target)
  (nth 0 target))

(defun edwf:target-engine (target)
  (nth 1 target))

(defun edwf:target-plotter (target)
  (nth 2 target))

(defun edwf:target-ext (target)
  (nth 3 target))

(defun edwf:plot-target-p (target)
  (= (edwf:target-engine target) "PLOT"))

(defun edwf:format-options ()
  (list
    (list "DXF"    "DXF  (기본)")
    (list "PDF"    "PDF  (DWG To PDF.pc3)")
    (list "DWF"    "DWF  (DWF6 ePlot.pc3)")
    (list "DXFPDF" "DXF + PDF")
    (list "PDFDWF" "PDF + DWF")
    (list "DXFDWF" "DXF + DWF")
    (list "ALL"    "DXF + PDF + DWF")))

(defun edwf:format-index (fmt / idx hit item)
  (setq fmt (strcase fmt)
        idx 0
        hit nil)
  (foreach item (edwf:format-options)
    (if (and (null hit) (= fmt (car item)))
      (setq hit idx))
    (setq idx (1+ idx)))
  (if hit hit 0))

(defun edwf:has-plot-targets-p ( / found target)
  (setq found nil)
  (foreach target (edwf:format-targets)
    (if (edwf:plot-target-p target)
      (setq found T)))
  found)

(defun edwf:first-plotter ( / plotter target)
  (setq plotter nil)
  (foreach target (edwf:format-targets)
    (if (and (null plotter) (edwf:plot-target-p target))
      (setq plotter (edwf:target-plotter target))))
  plotter)

(defun edwf:format-targets ( / fmt)
  (setq fmt (strcase (edwf:g "format")))
  (cond
    ((= fmt "PDF")
     (list
       (edwf:make-target "PDF" "PLOT" "DWG To PDF.pc3" ".pdf")))
    ((= fmt "DWF")
     (list
       (edwf:make-target "DWF" "PLOT" "DWF6 ePlot.pc3" ".dwf")))
    ((= fmt "DXFPDF")
     (list
       (edwf:make-target "DXF" "DXF" "" ".dxf")
       (edwf:make-target "PDF" "PLOT" "DWG To PDF.pc3" ".pdf")))
    ((= fmt "PDFDWF")
     (list
       (edwf:make-target "PDF" "PLOT" "DWG To PDF.pc3" ".pdf")
       (edwf:make-target "DWF" "PLOT" "DWF6 ePlot.pc3" ".dwf")))
    ((= fmt "DXFDWF")
     (list
       (edwf:make-target "DXF" "DXF" "" ".dxf")
       (edwf:make-target "DWF" "PLOT" "DWF6 ePlot.pc3" ".dwf")))
    ((= fmt "ALL")
     (list
       (edwf:make-target "DXF" "DXF" "" ".dxf")
       (edwf:make-target "PDF" "PLOT" "DWG To PDF.pc3" ".pdf")
       (edwf:make-target "DWF" "PLOT" "DWF6 ePlot.pc3" ".dwf")))
    (T
     (list
       (edwf:make-target "DXF" "DXF" "" ".dxf")))))

(defun edwf:ui-paper-list (layout / papers target)
  (setq papers nil)
  (foreach target (edwf:format-targets)
    (if (edwf:plot-target-p target)
      (setq papers
        (edwf:merge-ci-lists
          papers
          (edwf:get-papers-cached (edwf:target-plotter target) layout)))))
  papers)

(defun edwf:resolve-auto-paper (plotter layout pt-min pt-max
                                 / size target-w target-h papers dims
                                    paper-w paper-h fit-score dist-score
                                    best-fit best-fit-name
                                    best-fallback best-fallback-score)
  (setq size     (edwf:window-size-mm pt-min pt-max)
        target-w (car size)
        target-h (cadr size)
        papers   (edwf:get-papers-cached plotter layout))
  (foreach paper papers
    (setq dims (edwf:paper-dims-mm paper))
    (if dims
      (progn
        (setq paper-w (car dims)
              paper-h (cadr dims)
              fit-score (edwf:paper-fit-score paper-w paper-h target-w target-h))
        (if fit-score
          (if (or (null best-fit) (< fit-score best-fit))
            (setq best-fit      fit-score
                  best-fit-name paper))
          (progn
            (setq dist-score (edwf:paper-distance-score paper-w paper-h target-w target-h))
            (if (or (null best-fallback-score) (< dist-score best-fallback-score))
              (setq best-fallback-score dist-score
                    best-fallback       paper)))))))
  (if best-fit-name best-fit-name best-fallback))

(defun edwf:resolve-paper (plotter layout pt-min pt-max / paper)
  (setq paper (edwf:trim (edwf:g "paper")))
  (if (edwf:auto-paper-p paper)
    (edwf:resolve-auto-paper plotter layout pt-min pt-max)
    paper))

(defun edwf:landscape-p (width height)
  (> width height))

(defun edwf:paper-rotation-for-window (paper pt-min pt-max / dims size)
  (setq dims (if paper (edwf:paper-dims-mm paper))
        size (edwf:window-size-mm pt-min pt-max))
  (if (and dims
           (/= (edwf:landscape-p (car dims) (cadr dims))
               (edwf:landscape-p (car size) (cadr size))))
    1
    0))

(defun edwf:paper-orientation-key (pt-min pt-max / width height)
  (setq width  (abs (- (car  pt-max) (car  pt-min)))
        height (abs (- (cadr pt-max) (cadr pt-min))))
  (if (> width height) "_Landscape" "_Portrait"))

(defun edwf:apply-format (fmt / targets plotter ext)
  (edwf:s "format" (strcase fmt))
  (setq targets (edwf:format-targets)
        plotter (edwf:first-plotter)
        ext     (if targets (edwf:target-ext (car targets)) ".dxf"))
  (edwf:s "plotter" (if plotter plotter ""))
  (edwf:s "ext" ext)
  (edwf:s "paper" "AUTO"))

(defun edwf:set-format-by-index (idx / opt)
  (setq opt (nth idx (edwf:format-options)))
  (if opt
    (edwf:set-format (car opt))))

(defun edwf:set-format (fmt)
  (edwf:apply-format fmt)
  (set_tile "ed_paper" "자동")
  (set_tile "ed_ctb" (edwf:ctb-display (edwf:g "ctb")))
  (edwf:update-paper-list (edwf:g "plotter"))
  (edwf:update-ctb-list)
  (edwf:update-plot-option-modes))

;;; ============================================================
;;; 섹션 2: AutoCAD 버전 감지
;;; ============================================================

(defun edwf:acad-ver ()
  ;; ACADVER 예: "25.0s", "24.1", "25,0" (로컬라이즈)
  ;; atoi는 첫 비숫자 문자에서 중단 → 주 버전 정수 반환
  (atoi (getvar "ACADVER")))

;;; ============================================================
;;; 섹션 3: 유틸리티 - 중첩 폴더 생성
;;; ============================================================

(defun edwf:ensure-dir (path)
  (edwf:ensure-dir-r path 0))

(defun edwf:ensure-dir-r (path depth / parent)
  (cond
    ((vl-file-directory-p path) T)
    ((>= depth 20)
     (princ (strcat "\n  [경고] 폴더 생성 깊이 초과: " path))
     nil)
    (T
     (setq parent (vl-filename-directory path))
     (if (and parent (/= parent "") (/= parent path))
       (edwf:ensure-dir-r parent (1+ depth)))
     (vl-mkdir path)
     (vl-file-directory-p path))))

;;; ============================================================
;;; 섹션 4: 메인 명령
;;; ============================================================

(defun edwf:main-command ( / acad doc dcl-file dcl-id dlg-result)

  (setq acad (vlax-get-acad-object))
  (setq doc  (vla-get-activedocument acad))
  (edwf:init doc)

  (princ "\n================================================")
  (princ "\n  DXF/PDF/DWF 일괄 내보내기  v5")
  (princ (strcat "\n  AutoCAD R" (itoa (edwf:acad-ver))))
  (princ (strcat "\n  엔진: "
    (if (>= (edwf:acad-ver) 21)
      "PDF/DWF는 ActiveX (+ -PLOT 폴백) / DXF는 WBLOCK + SaveAs"
      "PDF/DWF는 -PLOT / DXF는 WBLOCK + SaveAs")))
  (princ "\n================================================")

  (setq dcl-file (edwf:find-dcl))

  (cond
    ((null dcl-file)
     (princ "\n  DCL 없음 → 텍스트 모드")
     (edwf:textmode doc))
    (T
     (setq dcl-id (load_dialog dcl-file))
     (cond
       ((< dcl-id 0)
        (princ "\n  DCL 로드 실패 → 텍스트 모드")
        (edwf:textmode doc))
       (T
        (setq dlg-result (edwf:run-dialog dcl-id))
        (unload_dialog dcl-id)
        (cond
          ((= dlg-result 1) (edwf:run-export doc))
          (T                (princ "\n취소됨.")))))))
  (princ))

(defun c:EXPORT-SMART ()
  (edwf:main-command))


;;; ============================================================
;;; 섹션 5: DCL 파일 탐색
;;; ============================================================

(defun edwf:find-dcl ( / dcl-name candidates result f)
  ;; DCL 탐색: DWG 파일 폴더 우선 (edwf:init에서 이미 설정됨)
  ;; LSP + DCL + DWG 를 같은 폴더에 두면 어느 PC에서든 동작
  (setq dcl-name "export_dwf_ui.dcl"
        result   nil)
  (setq candidates
    (list
      ;; 1순위: DWG와 같은 폴더 (edwf:init에서 설정한 folder값)
      (strcat (edwf:g "folder") "\\" dcl-name)
      ;; 2순위: AutoCAD 검색 경로
      (findfile dcl-name)))
  (foreach c candidates
    (if (and (null result) c)
      (progn
        (setq f (open c "r"))
        (if f
          (progn
            (close f)
            (setq result c))))))
  result)

;;; ============================================================
;;; 섹션 6: 플롯 정보 취득 (용지, CTB)
;;; ============================================================

(defun edwf:get-papers (plotter layout / old-cfg result lst err)
  ;; 임시로 플로터를 변경하여 용지 목록 취득 후 원래대로 복원
  (setq old-cfg (vl-catch-all-apply 'vla-get-ConfigName (list layout)))
  (setq err (vl-catch-all-apply 'vla-put-ConfigName (list layout plotter)))
  (if (not (vl-catch-all-error-p err))
    (progn
      (vl-catch-all-apply 'vla-RefreshPlotDeviceInfo (list layout))
      (setq result (vl-catch-all-apply 'vla-GetCanonicalMediaNames (list layout)))
      (if (not (vl-catch-all-error-p result))
        (setq lst (vlax-safearray->list (vlax-variant-value result))))))
  ;; 원래 플로터로 복원
  (if (not (vl-catch-all-error-p old-cfg))
    (vl-catch-all-apply 'vla-put-ConfigName (list layout old-cfg)))
  (if lst (vl-sort lst '<) nil))

(defun edwf:get-ctbs (layout / result lst)
  (vl-catch-all-apply 'vla-RefreshPlotDeviceInfo (list layout))
  (setq result (vl-catch-all-apply 'vla-GetPlotStyleTableNames (list layout)))
  (if (not (vl-catch-all-error-p result))
    (setq lst (vlax-safearray->list (vlax-variant-value result))))
  (if lst (vl-sort (vl-remove-if '(lambda (x) (= x "")) lst) '<) nil))

;;; ============================================================
;;; 섹션 7: 다이얼로그
;;; ============================================================

(defun edwf:run-dialog (dcl-id / dlg-result)
  (if (not (new_dialog "export_dwf_dialog" dcl-id))
    (progn (princ "\n다이얼로그 생성 실패.") 0)
    (progn
      (edwf:dlg-init)
      (edwf:dlg-callbacks)
      (setq dlg-result (start_dialog))

      ;; 샘플 선택 루프 (done_dialog 2)
      (while (= dlg-result 2)
        (edwf:pick-sample)
        (if (not (new_dialog "export_dwf_dialog" dcl-id))
          (progn (princ "\n재오픈 실패.") (setq dlg-result 0))
          (progn
            (edwf:dlg-init)
            (edwf:dlg-callbacks)
            (if (edwf:g "sample-lyr")
              (set_tile "txt_sample"
                (strcat "[OK] " (edwf:g "sample-lyr")
                  (if (and (edwf:g "sample-aci")
                           (> (edwf:g "sample-aci") 0))
                    (strcat "  ACI:" (itoa (edwf:g "sample-aci")))
                    "  (ByLayer)"))))
            (edwf:dlg-preview)
            (setq dlg-result (start_dialog)))))
      dlg-result)))

(defun edwf:dlg-init ()
  (set_tile "rb_sample"  (if (= (edwf:g "mode") "layer") "0" "1"))
  (set_tile "rb_layer"   (if (= (edwf:g "mode") "layer") "1" "0"))
  (set_tile "ed_layer"   (if (edwf:g "layer") (edwf:g "layer") ""))
  (set_tile "ed_aci"     (if (> (edwf:g "aci") 0)
                           (itoa (edwf:g "aci")) ""))
  (set_tile "ed_folder"  (edwf:g "folder"))
  (set_tile "ed_prefix"  (edwf:g "prefix"))
  (set_tile "ed_paper"   (edwf:paper-display (edwf:g "paper")))
  (set_tile "ed_ctb"     (edwf:ctb-display (edwf:g "ctb")))
  (set_tile "ed_minsize" (itoa (edwf:g "minsize")))
  (set_tile "txt_count"  "감지된 개수: -")

  (edwf:update-format-list)
  (edwf:update-crop-mode-list)
  (edwf:update-paper-list (edwf:g "plotter"))
  (edwf:update-ctb-list)
  (edwf:update-plot-option-modes))

(defun edwf:update-format-list ( / opt)
  (start_list "cb_format")
  (foreach opt (edwf:format-options)
    (add_list (cadr opt)))
  (end_list)
  (set_tile "cb_format" (itoa (edwf:format-index (edwf:g "format")))))

(defun edwf:update-plot-option-modes ( / mode)
  (setq mode (if (edwf:has-plot-targets-p) 0 1))
  (mode_tile "cb_paper" mode)
  (mode_tile "ed_paper" mode)
  (mode_tile "cb_ctb" mode)
  (mode_tile "ed_ctb" mode))

(defun edwf:update-crop-mode-list ()
  (start_list "cb_crop_mode")
  (add_list "테두리 기준")
  (add_list "내부 내용 기준 크롭")
  (end_list)
  (set_tile "cb_crop_mode"
    (if (= (edwf:g "crop-mode") "content") "1" "0")))

(defun edwf:update-paper-list (plotter / acad doc layout)
  (setq acad   (vlax-get-acad-object)
        doc    (vla-get-activedocument acad)
        layout (vla-get-activelayout doc))
  (if (edwf:has-plot-targets-p)
    (progn
      (setq *edwf:paper-list* (edwf:ui-paper-list layout))
      (start_list "cb_paper")
      (add_list "- 자동 맞춤 (기본) -")
      (add_list "- 특수/사용자정의 용지명 -")
      (foreach p *edwf:paper-list* (add_list p))
      (end_list)
      (set_tile "cb_paper"
        (cond
          ((edwf:auto-paper-p (edwf:g "paper")) "0")
          ((edwf:index-ci (edwf:g "paper") *edwf:paper-list*)
           (itoa (+ 2 (edwf:index-ci (edwf:g "paper") *edwf:paper-list*))))
          (T "1"))))
    (progn
      (setq *edwf:paper-list* nil)
      (start_list "cb_paper")
      (add_list "- DXF에서는 사용 안 함 -")
      (end_list)
      (set_tile "cb_paper" "0"))))

(defun edwf:update-ctb-list ( / acad doc layout)
  (setq acad   (vlax-get-acad-object)
        doc    (vla-get-activedocument acad)
        layout (vla-get-activelayout doc))
  (if (edwf:has-plot-targets-p)
    (progn
      (setq *edwf:ctb-list* (edwf:get-ctbs layout))
      (start_list "cb_ctb")
      (add_list "- 없음 (기본) -")
      (add_list "- 스타일명 직접 입력 -")
      (foreach c *edwf:ctb-list* (add_list c))
      (end_list)
      (set_tile "cb_ctb"
        (cond
          ((edwf:none-ctb-p (edwf:g "ctb")) "0")
          ((edwf:index-ci (edwf:g "ctb") *edwf:ctb-list*)
           (itoa (+ 2 (edwf:index-ci (edwf:g "ctb") *edwf:ctb-list*))))
          (T "1"))))
    (progn
      (setq *edwf:ctb-list* nil)
      (start_list "cb_ctb")
      (add_list "- DXF에서는 사용 안 함 -")
      (end_list)
      (set_tile "cb_ctb" "0"))))

(defun edwf:cb-format-action (val)
  (edwf:set-format-by-index (atoi val)))

(defun edwf:cb-paper-action (val / idx p)
  (setq idx (atoi val))
  (if (not (edwf:has-plot-targets-p))
    (progn
      (set_tile "ed_paper" "자동")
      (edwf:s "paper" "AUTO"))
    (cond
      ((= idx 0)
       (set_tile "ed_paper" "자동")
       (edwf:s "paper" "AUTO"))
      ((= idx 1)
       (set_tile "ed_paper"
         (if (edwf:auto-paper-p (edwf:g "paper")) "" (edwf:g "paper"))))
      (T
       (setq p (nth (- idx 2) *edwf:paper-list*))
       (set_tile "ed_paper" p)
       (edwf:s "paper" p)))))

(defun edwf:cb-ctb-action (val / idx c)
  (setq idx (atoi val))
  (if (not (edwf:has-plot-targets-p))
    (progn
      (set_tile "ed_ctb" "none")
      (edwf:s "ctb" "none"))
    (cond
      ((= idx 0) (set_tile "ed_ctb" "none") (edwf:s "ctb" "none"))
      ((= idx 1)
       (set_tile "ed_ctb"
         (if (edwf:none-ctb-p (edwf:g "ctb")) "none" (edwf:g "ctb"))))
      (T
        (setq c (nth (- idx 2) *edwf:ctb-list*))
        (set_tile "ed_ctb" c)
        (edwf:s "ctb" c)))))

(defun edwf:cb-crop-mode-action (val)
  (if (= (atoi val) 1)
    (edwf:s "crop-mode" "content")
    (edwf:s "crop-mode" "border")))

(defun edwf:dlg-callbacks ()
  (action_tile "rb_sample" "(edwf:s \"mode\" \"sample\")")
  (action_tile "rb_layer"  "(edwf:s \"mode\" \"layer\")")
  (action_tile "btn_pick"  "(done_dialog 2)")

  (action_tile "cb_format" "(edwf:cb-format-action $value)")

  (action_tile "btn_browse"  "(edwf:browse-folder)")
  (action_tile "btn_preview" "(edwf:dlg-save)(edwf:dlg-preview)")

  (action_tile "ed_layer"   "(edwf:s \"layer\"   $value)")
  (action_tile "ed_aci"
    "(edwf:s \"aci\" (if (= $value \"\") 0 (atoi $value)))")
  (action_tile "ed_folder"  "(edwf:s \"folder\"  $value)")
  (action_tile "ed_prefix"  "(edwf:s \"prefix\"  $value)")
  (action_tile "cb_paper"   "(edwf:cb-paper-action $value)")
  (action_tile "ed_paper"   "(edwf:s \"paper\"   $value)")
  (action_tile "cb_ctb"     "(edwf:cb-ctb-action $value)")
  (action_tile "ed_ctb"     "(edwf:s \"ctb\"     $value)")
  (action_tile "cb_crop_mode" "(edwf:cb-crop-mode-action $value)")
  (action_tile "ed_minsize"
    "(edwf:s \"minsize\" (if (= $value \"\") 500 (atoi $value)))")

  (action_tile "accept" "(edwf:dlg-save)(done_dialog 1)")
  (action_tile "cancel" "(done_dialog 0)"))

(defun edwf:dlg-save ( / tmp-min tmp-aci)
  (edwf:s "layer"  (get_tile "ed_layer"))
  (edwf:s "folder" (get_tile "ed_folder"))
  (edwf:s "prefix" (get_tile "ed_prefix"))
  (edwf:s "paper"
    (if (edwf:auto-paper-p (get_tile "ed_paper")) "AUTO" (edwf:trim (get_tile "ed_paper"))))
  (edwf:s "ctb"
    (if (edwf:none-ctb-p (get_tile "ed_ctb")) "none" (edwf:trim (get_tile "ed_ctb"))))
  (edwf:s "crop-mode"
    (if (= (get_tile "cb_crop_mode") "1") "content" "border"))
  (setq tmp-min (atoi (get_tile "ed_minsize")))
  (edwf:s "minsize" (if (> tmp-min 0) tmp-min 500))
  (setq tmp-aci (get_tile "ed_aci"))
  (edwf:s "aci" (if (or (null tmp-aci) (= tmp-aci "")) 0 (atoi tmp-aci))))

(defun edwf:get-detect-count (doc / bds)
  (setq bds (edwf:detect doc))
  (if bds (length bds) 0))

(defun edwf:update-count-tile (doc)
  (set_tile "txt_count"
    (strcat "감지된 개수: " (itoa (edwf:get-detect-count doc)) "개")))

(defun edwf:dlg-preview ( / doc)
  (setq doc (vla-get-activedocument (vlax-get-acad-object)))
  (edwf:update-count-tile doc))

(defun edwf:browse-folder ( / shell fo fp)
  (setq shell
    (vl-catch-all-apply 'vlax-create-object (list "Shell.Application")))
  (if (and shell (not (vl-catch-all-error-p shell)))
    (progn
      (setq fo
        (vl-catch-all-apply 'vlax-invoke-method
          (list shell 'BrowseForFolder 0 "저장 폴더 선택" 0 "")))
      (if (and fo (not (vl-catch-all-error-p fo)))
        (progn
          (setq fp
            (vl-catch-all-apply 'vlax-get-property
              (list (vlax-get-property fo 'Self) 'Path)))
          (if (and fp (not (vl-catch-all-error-p fp)))
            (progn
              (if (= (substr fp (strlen fp)) "\\")
                (setq fp (substr fp 1 (1- (strlen fp)))))
              (edwf:s "folder" fp)
              (set_tile "ed_folder" fp)))))
      (if (and fo (not (vl-catch-all-error-p fo)))
        (vlax-release-object fo))
      (vlax-release-object shell))))

;;; ============================================================
;;; 섹션 8: 샘플 선택
;;; ============================================================

(defun edwf:pick-sample ( / ent obj lyr dxf-color)
  (princ "\n테두리 객체를 클릭하세요 (INSERT 또는 LWPOLYLINE)...")
  (setq ent (car (entsel "\n선택: ")))
  (if (null ent)
    (princ "\n  선택 취소.")
    (progn
      (setq obj (vlax-ename->vla-object ent))
      (setq lyr (vla-get-layer obj))
      (edwf:s "sample-lyr" lyr)
      (edwf:s "layer"      lyr)
      (setq dxf-color (cdr (assoc 62 (entget ent))))
      (if (and dxf-color (> dxf-color 0) (< dxf-color 256))
        (progn
          (edwf:s "sample-aci" dxf-color)
          (edwf:s "aci"        dxf-color)
          (princ (strcat "\n  레이어: " lyr "  ACI: " (itoa dxf-color))))
        (progn
          (edwf:s "sample-aci" 0)
          (edwf:s "aci"        0)
          (princ (strcat "\n  레이어: " lyr "  색상: ByLayer")))))))

;;; ============================================================
;;; 섹션 9: 테두리 감지
;;; ============================================================

(defun edwf:detect (doc / ss flt-i flt-p
                         i ent obj bbox pt-min pt-max
                         borders minsize lyr aci)
  (setq borders nil
        minsize (edwf:g "minsize")
        lyr     (edwf:g "layer")
        aci     (edwf:g "aci"))

  ;; INSERT 필터
  (setq flt-i (list '(0 . "INSERT") '(410 . "Model")))
  (if (and lyr (/= lyr ""))
    (setq flt-i (append flt-i (list (cons 8 lyr)))))
  (if (and aci (> aci 0) (< aci 256))
    (setq flt-i (append flt-i (list (cons 62 aci)))))

  ;; LWPOLYLINE 필터 (닫힌 것만)
  (setq flt-p (list '(0 . "LWPOLYLINE") '(70 . 1) '(410 . "Model")))
  (if (and lyr (/= lyr ""))
    (setq flt-p (append flt-p (list (cons 8 lyr)))))
  (if (and aci (> aci 0) (< aci 256))
    (setq flt-p (append flt-p (list (cons 62 aci)))))

  (foreach flt (list flt-i flt-p)
    (setq ss (ssget "X" flt))
    (if ss
      (progn
        (setq i 0)
        (repeat (sslength ss)
          (setq ent (ssname ss i)
                obj (vlax-ename->vla-object ent))
          (setq bbox (edwf:get-bbox-safe obj))
          (if bbox
            (progn
              (setq pt-min (car bbox)
                    pt-max (cadr bbox))
              (if (and
                    (> (- (car  pt-max) (car  pt-min)) minsize)
                    (> (- (cadr pt-max) (cadr pt-min)) minsize))
                (if (not (edwf:bbox-dup-p borders pt-min pt-max))
                  (setq borders (cons (list pt-min pt-max ent) borders))))))
          (setq i (1+ i))))))
  borders)

(defun edwf:bbox-dup-p (borders pt-min pt-max / tol)
  (setq tol 50)
  (vl-some
    (function
      (lambda (b)
        (and
          (< (abs (- (car  (car  b)) (car  pt-min))) tol)
          (< (abs (- (cadr (car  b)) (cadr pt-min))) tol)
          (< (abs (- (car  (cadr b)) (car  pt-max))) tol)
          (< (abs (- (cadr (cadr b)) (cadr pt-max))) tol))))
    borders))

(defun edwf:get-bbox-safe (obj / cur-min cur-max result)
  (setq result
    (vl-catch-all-apply
      (function
        (lambda ()
          (vla-GetBoundingBox obj 'cur-min 'cur-max)))
      nil))
  (if (vl-catch-all-error-p result)
    nil
    (list
      (vlax-safearray->list cur-min)
      (vlax-safearray->list cur-max))))

(defun edwf:merge-bbox (cur bbox)
  (if cur
    (list
      (list (min (car  (car  cur)) (car  (car  bbox)))
            (min (cadr (car  cur)) (cadr (car  bbox))))
      (list (max (car  (cadr cur)) (car  (cadr bbox)))
            (max (cadr (cadr cur)) (cadr (cadr bbox)))))
    bbox))

(defun edwf:clamp-bbox (bbox outer-min outer-max)
  (list
    (list (max (car  (car  bbox)) (car  outer-min))
          (max (cadr (car  bbox)) (cadr outer-min)))
    (list (min (car  (cadr bbox)) (car  outer-max))
          (min (cadr (cadr bbox)) (cadr outer-max)))))

(defun edwf:bbox-matches-outer-p (bbox outer-min outer-max / tol)
  (setq tol (* 0.001
               (max (- (car  outer-max) (car  outer-min))
                    (- (cadr outer-max) (cadr outer-min)))))
  (if (< tol 0.01)
    (setq tol 0.01))
  (and
    (< (abs (- (car  (car  bbox)) (car  outer-min))) tol)
    (< (abs (- (cadr (car  bbox)) (cadr outer-min))) tol)
    (< (abs (- (car  (cadr bbox)) (car  outer-max))) tol)
    (< (abs (- (cadr (cadr bbox)) (cadr outer-max))) tol)))

(defun edwf:bbox-inside-outer-p (bbox outer-min outer-max / tol)
  (setq tol (* 0.001
               (max (- (car  outer-max) (car  outer-min))
                    (- (cadr outer-max) (cadr outer-min)))))
  (if (< tol 0.01)
    (setq tol 0.01))
  (and
    (>= (car  (car  bbox)) (- (car  outer-min) tol))
    (>= (cadr (car  bbox)) (- (cadr outer-min) tol))
    (<= (car  (cadr bbox)) (+ (car  outer-max) tol))
    (<= (cadr (cadr bbox)) (+ (cadr outer-max) tol))))

(defun edwf:delete-object-safe (obj)
  (if obj
    (vl-catch-all-apply 'vla-delete (list obj))))

(defun edwf:object-list (value / tmp)
  (setq tmp (vl-catch-all-apply 'vlax-variant-value (list value)))
  (if (not (vl-catch-all-error-p tmp))
    (setq value tmp))
  (setq tmp (vl-catch-all-apply 'vlax-safearray->list (list value)))
  (if (vl-catch-all-error-p tmp)
    (if (listp value) value nil)
    tmp))

(defun edwf:inner-window (pt-min pt-max / width height inset)
  (setq width  (- (car  pt-max) (car  pt-min))
        height (- (cadr pt-max) (cadr pt-min))
        inset  (* 0.002 (min width height)))
  (if (< inset 0.001)
    (setq inset 0.001))
  (if (or (<= width (* 2 inset))
          (<= height (* 2 inset)))
    nil
     (list
       (list (+ (car  pt-min) inset) (+ (cadr pt-min) inset))
       (list (- (car  pt-max) inset) (- (cadr pt-max) inset)))))

(defun edwf:get-window-content-bbox (outer-min outer-max border-ent / inner ss i ent obj bbox crop-bbox)
  (setq inner (edwf:inner-window outer-min outer-max))
  (if (null inner)
    nil
    (progn
      (setq ss (ssget "_C" (car inner) (cadr inner) (list (cons 410 "Model"))))
      (if ss
        (progn
          (setq i 0)
          (repeat (sslength ss)
            (setq ent (ssname ss i))
            (if (or (null border-ent) (/= ent border-ent))
              (progn
                (setq obj (vlax-ename->vla-object ent)
                      bbox (edwf:get-bbox-safe obj))
                (if (and bbox
                         (edwf:bbox-inside-outer-p bbox outer-min outer-max))
                  (setq crop-bbox (edwf:merge-bbox crop-bbox bbox)))))
            (setq i (1+ i)))
          (if crop-bbox
            (edwf:clamp-bbox crop-bbox outer-min outer-max)
            nil))
        nil))))

(defun edwf:get-insert-content-bbox (border-ent outer-min outer-max / obj copy exploded item bbox crop-bbox)
  (setq obj (vlax-ename->vla-object border-ent))
  (if (or (not (vlax-method-applicable-p obj 'Copy))
          (not (vlax-method-applicable-p obj 'Explode)))
    nil
    (progn
      (setq copy (vl-catch-all-apply 'vla-copy (list obj)))
      (if (or (null copy) (vl-catch-all-error-p copy))
        nil
        (progn
          (setq exploded (vl-catch-all-apply 'vlax-invoke-method (list copy 'Explode)))
          (edwf:delete-object-safe copy)
          (if (vl-catch-all-error-p exploded)
            nil
            (progn
              (foreach item (edwf:object-list exploded)
                (setq bbox (edwf:get-bbox-safe item))
                (if (and bbox
                         (not (edwf:bbox-matches-outer-p bbox outer-min outer-max)))
                  (setq crop-bbox (edwf:merge-bbox crop-bbox bbox)))
                (edwf:delete-object-safe item))
              (if crop-bbox
                (edwf:clamp-bbox crop-bbox outer-min outer-max)
                nil))))))))

(defun edwf:get-content-bbox (bd / outer-min outer-max border-ent border-type)
  (setq outer-min (car bd)
        outer-max (cadr bd)
        border-ent (if (> (length bd) 2) (caddr bd))
        border-type (if border-ent (cdr (assoc 0 (entget border-ent))) nil))
  (cond
    ((null border-ent) nil)
    ((= border-type "INSERT")
     (edwf:get-insert-content-bbox border-ent outer-min outer-max))
    (T
     (edwf:get-window-content-bbox outer-min outer-max border-ent))))

(defun edwf:get-output-window (bd / content-bbox)
  (if (= (edwf:g "crop-mode") "content")
    (progn
      (setq content-bbox (edwf:get-content-bbox bd))
      (if content-bbox
        content-bbox
        (list (car bd) (cadr bd))))
    (list (car bd) (cadr bd))))

;;; ============================================================
;;; 섹션 10: 정렬
;;; ============================================================

(defun edwf:sort (borders / hs avg-h thr)
  (if (null borders) nil
    (progn
      (setq hs
        (mapcar
          (function (lambda (b)
            (abs (- (cadr (cadr b)) (cadr (car b))))))
          borders))
      (setq avg-h (/ (apply '+ hs) (float (length hs))))
      (setq thr   (* 0.40 avg-h))
      (vl-sort borders
        (function
          (lambda (a b / ay by ax bx)
            (setq ay (cadr (cadr a)) by (cadr (cadr b))
                  ax (car  (car  a)) bx (car  (car  b)))
            (if (> (abs (- ay by)) thr)
              (> ay by) (< ax bx))))))))

;;; ============================================================
;;; 섹션 11: 플롯 엔진
;;; ============================================================

(defun edwf:plot-one (pt-min pt-max filepath plotter doc layout)
  (if (>= (edwf:acad-ver) 21)
    (edwf:plot-activex pt-min pt-max filepath plotter doc layout)
    (edwf:plot-command pt-min pt-max filepath plotter layout)))

;;; ── 방법 A: ActiveX (R21+) ─────────────────────────────────
;;; ActiveX core attempt. The caller restores state and decides fallback.
(defun edwf:plot-activex-core (pt-min pt-max filepath plotter
                                doc layout
                                / plot-obj win-min win-max applied
                                  paper-name rotation ctb-name)
  (setq paper-name (edwf:resolve-paper plotter layout pt-min pt-max)
        rotation   (edwf:paper-rotation-for-window paper-name pt-min pt-max)
        ctb-name   (edwf:effective-ctb))
  (vla-put-ConfigName layout plotter)
  (vla-RefreshPlotDeviceInfo layout)
  (if paper-name
    (progn
      (vla-put-CanonicalMediaName layout paper-name)
      (setq applied (vla-get-CanonicalMediaName layout))
      (if (not (wcmatch (strcase applied) (strcase paper-name)))
        (princ (strcat "\n    [경고] 용지 '" paper-name "' 등록 안됨 → 기본 용지로 출력됨")))))
  (if (/= ctb-name "")
    (vla-put-StyleSheet layout ctb-name)
    (vl-catch-all-apply 'vla-put-StyleSheet (list layout "")))
  (vla-put-PlotType layout 4)
  (vla-put-UseStandardScale layout :vlax-true)
  (vla-put-StandardScale layout 0)
  (vla-put-PlotRotation layout rotation)
  (vla-put-CenterPlot layout :vlax-true)

  (setq win-min (vlax-make-safearray vlax-vbDouble '(0 . 1))
        win-max (vlax-make-safearray vlax-vbDouble '(0 . 1)))
  (vlax-safearray-put-element win-min 0 (car  pt-min))
  (vlax-safearray-put-element win-min 1 (cadr pt-min))
  (vlax-safearray-put-element win-max 0 (car  pt-max))
  (vlax-safearray-put-element win-max 1 (cadr pt-max))
  (vla-SetWindowToPlot layout win-min win-max)

  (setq plot-obj (vlax-get-property doc 'Plot))
  (if (null plot-obj)
    (progn
      (princ "\n    Plot 객체 실패 → -PLOT 폴백")
      'fallback)
    (progn
      (vla-PlotToFile plot-obj filepath)
      T)))

;;; Safe override: keep batch loop alive by catching ActiveX exceptions outside.
(defun edwf:plot-activex (pt-min pt-max filepath plotter
                           doc layout
                           / old-cfg old-paper-name old-ctb-name old-ptype old-ustd
                             old-scale old-rot old-center
                             old-bgplot result result-msg)
  (setq old-bgplot (getvar "BACKGROUNDPLOT"))
  (setvar "BACKGROUNDPLOT" 0)

  ;; 레이아웃 백업
  (setq old-cfg    (vl-catch-all-apply 'vla-get-ConfigName       (list layout))
        old-paper-name (vl-catch-all-apply 'vla-get-CanonicalMediaName (list layout))
        old-ctb-name   (vl-catch-all-apply 'vla-get-StyleSheet       (list layout))
        old-ptype  (vl-catch-all-apply 'vla-get-PlotType         (list layout))
        old-ustd   (vl-catch-all-apply 'vla-get-UseStandardScale (list layout))
        old-scale  (vl-catch-all-apply 'vla-get-StandardScale    (list layout))
        old-rot    (vl-catch-all-apply 'vla-get-PlotRotation     (list layout))
        old-center (vl-catch-all-apply 'vla-get-CenterPlot       (list layout)))

  (setq result
    (vl-catch-all-apply
      'edwf:plot-activex-core
      (list pt-min pt-max filepath plotter doc layout)))

  ;; 복원
  (edwf:restore-layout layout
    old-cfg old-paper-name old-ctb-name old-ptype old-ustd old-scale old-rot old-center)
  (setvar "BACKGROUNDPLOT" old-bgplot)

  ;; 결과
  (cond
    ((vl-catch-all-error-p result)
     (setq result-msg (vl-catch-all-error-message result))
     (if (not (wcmatch (strcase result-msg) "*CANCEL*,*QUIT*,*EXIT*"))
       (progn
         (princ (strcat "\n    ActiveX 오류: "
                  result-msg
                  " → -PLOT 폴백"))
         (edwf:plot-command pt-min pt-max filepath plotter layout))
       nil))
    ((eq result 'fallback)
     (edwf:plot-command pt-min pt-max filepath plotter layout))
    ((findfile filepath)
     (princ " OK") T)
    (T
     (princ " FAIL") nil)))

(defun edwf:restore-layout (layout cfg paper ctb ptype ustd scale rot center)
  (if (and cfg    (not (vl-catch-all-error-p cfg)))
    (vl-catch-all-apply 'vla-put-ConfigName       (list layout cfg)))
  (if (and paper  (not (vl-catch-all-error-p paper)))
    (vl-catch-all-apply 'vla-put-CanonicalMediaName (list layout paper)))
  (if (and ctb    (not (vl-catch-all-error-p ctb)))
    (vl-catch-all-apply 'vla-put-StyleSheet       (list layout ctb)))
  (if (and ptype  (not (vl-catch-all-error-p ptype)))
    (vl-catch-all-apply 'vla-put-PlotType         (list layout ptype)))
  (if (and ustd   (not (vl-catch-all-error-p ustd)))
    (vl-catch-all-apply 'vla-put-UseStandardScale (list layout ustd)))
  (if (and scale  (not (vl-catch-all-error-p scale)))
    (vl-catch-all-apply 'vla-put-StandardScale    (list layout scale)))
  (if (and rot    (not (vl-catch-all-error-p rot)))
    (vl-catch-all-apply 'vla-put-PlotRotation     (list layout rot)))
  (if (and center (not (vl-catch-all-error-p center)))
    (vl-catch-all-apply 'vla-put-CenterPlot       (list layout center))))

;;; ── 방법 B: -PLOT 명령 (R20 이하 / 폴백) ───────────────────
;;; Model 탭 + 가상 플로터 기준 프롬프트 순서.
;;; "Scale lineweights" 프롬프트가 없는 AutoCAD 버전에서는
;;; 이후 응답이 밀릴 수 있음 (FAIL 메시지로 안내).
(defun edwf:plot-command (pt-min pt-max filepath plotter layout
                           / old-ce old-bg old-fd old-err
                             x1s y1s x2s y2s plot-ok
                             paper-name orient-key ctb-name use-ctb)
  (setq old-err *error* plot-ok T)
  (defun *error* (msg)
    (setq plot-ok nil)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\n    -PLOT 오류: " msg)))
    (setvar "CMDECHO"        old-ce)
    (setvar "BACKGROUNDPLOT" old-bg)
    (setvar "FILEDIA"        old-fd)
    (setq *error* old-err))

  (setq old-ce (getvar "CMDECHO")
        old-bg (getvar "BACKGROUNDPLOT")
        old-fd (getvar "FILEDIA"))
  (setvar "CMDECHO" 0)
  (setvar "BACKGROUNDPLOT" 0)
  (setvar "FILEDIA" 0)

  (while (> (getvar "CMDACTIVE") 0) (command ""))

  (setq x1s (rtos (car  pt-min) 2 4)
        y1s (rtos (cadr pt-min) 2 4)
        x2s (rtos (car  pt-max) 2 4)
        y2s (rtos (cadr pt-max) 2 4)
        paper-name (edwf:resolve-paper plotter layout pt-min pt-max)
        orient-key (edwf:paper-orientation-key pt-min pt-max)
        ctb-name   (edwf:effective-ctb)
        use-ctb    (/= ctb-name ""))

  (if use-ctb
    (command
      "_.-PLOT"
      "_Yes"                          ; 상세 설정
      ""                              ; 현재 레이아웃
      plotter                         ; 플로터
      (if paper-name paper-name "")   ; 용지
      ""                              ; 단위 (현재 유지)
      orient-key                      ; 방향
      "_No"                           ; 뒤집기
      "_Window"                       ; 영역
      (strcat x1s "," y1s)            ; 좌하단
      (strcat x2s "," y2s)            ; 우상단
      "_Fit"                          ; 스케일
      "0,0"                           ; 오프셋
      "_Yes"                          ; 플롯 스타일
      ctb-name                        ; CTB
      "_Yes"                          ; 선가중치
      "_No"                           ; 선가중치 스케일링
      "_Yes"                          ; 파일에 플롯 (가상 플로터 필수)
      filepath                        ; 파일 경로
      "_No"                           ; 설정 저장 안 함
      "_Yes"                          ; 진행
    )
    (command
      "_.-PLOT"
      "_Yes"                          ; 상세 설정
      ""                              ; 현재 레이아웃
      plotter                         ; 플로터
      (if paper-name paper-name "")   ; 용지
      ""                              ; 단위 (현재 유지)
      orient-key                      ; 방향
      "_No"                           ; 뒤집기
      "_Window"                       ; 영역
      (strcat x1s "," y1s)            ; 좌하단
      (strcat x2s "," y2s)            ; 우상단
      "_Fit"                          ; 스케일
      "0,0"                           ; 오프셋
      "_No"                           ; 플롯 스타일 없음
      "_Yes"                          ; 선가중치
      "_No"                           ; 선가중치 스케일링
      "_Yes"                          ; 파일에 플롯 (가상 플로터 필수)
      filepath                        ; 파일 경로
      "_No"                           ; 설정 저장 안 함
      "_Yes"                          ; 진행
    ))

  (setvar "CMDECHO"        old-ce)
  (setvar "BACKGROUNDPLOT" old-bg)
  (setvar "FILEDIA"        old-fd)
  (setq *error* old-err)

  (if plot-ok
    (if (findfile filepath)
      (progn (princ " OK") T)
      (progn (princ " FAIL (프롬프트 불일치 가능)") nil))
    nil))

(defun edwf:dxf-save-type ()
  (cond
    ((boundp 'ac2013_dxf) ac2013_dxf)
    ((boundp 'ac2010_dxf) ac2010_dxf)
    ((boundp 'ac2007_dxf) ac2007_dxf)
    ((boundp 'ac2004_dxf) ac2004_dxf)
    ((boundp 'ac2000_dxf) ac2000_dxf)
    ((boundp 'acR12_dxf) acR12_dxf)
    (T nil)))

(defun edwf:delete-file-safe (path)
  (if (and path (findfile path))
    (vl-file-delete path)))

(defun edwf:window-objects (pt-min pt-max / ss i ent obj bbox objs)
  (setq objs nil
        ss   (ssget "_C" pt-min pt-max (list (cons 410 "Model"))))
  (if ss
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq ent  (ssname ss i)
              obj  (vlax-ename->vla-object ent)
              bbox (edwf:get-bbox-safe obj))
        (if (and bbox (edwf:bbox-inside-outer-p bbox pt-min pt-max))
          (setq objs (cons obj objs)))
        (setq i (1+ i)))))
  (reverse objs))

(defun edwf:delete-selection-set-safe (doc name / ssets sset)
  (setq ssets (vla-get-SelectionSets doc)
        sset  (vl-catch-all-apply 'vla-Item (list ssets name)))
  (if (not (vl-catch-all-error-p sset))
    (vl-catch-all-apply 'vla-Delete (list sset))))

(defun edwf:make-selection-set (doc name objs / sset arr idx)
  (if objs
    (progn
      (edwf:delete-selection-set-safe doc name)
      (setq sset (vla-Add (vla-get-SelectionSets doc) name)
            arr  (vlax-make-safearray vlax-vbObject (cons 0 (1- (length objs))))
            idx  0)
      (foreach obj objs
        (vlax-safearray-put-element arr idx obj)
        (setq idx (1+ idx)))
      (vla-AddItems sset arr)
      sset)))

(defun edwf:export-dxf (pt-min pt-max filepath doc / objs sset temp-dwg temp-doc docs save-type result)
  (setq objs      (edwf:window-objects pt-min pt-max)
        save-type (edwf:dxf-save-type))
  (cond
    ((null objs)
     (princ " FAIL (객체 없음)")
     nil)
    ((null save-type)
     (princ " FAIL (DXF 저장 형식 없음)")
     nil)
    (T
     (setq sset     (edwf:make-selection-set doc "EDWF_TMP_SSET" objs)
           temp-dwg (vl-filename-mktemp "edwf_sheet_" (edwf:g "folder") ".dwg"))
     (edwf:delete-file-safe filepath)
     (setq result (vl-catch-all-apply 'vla-WBlock (list doc temp-dwg sset)))
     (if sset
       (vl-catch-all-apply 'vla-Delete (list sset)))
     (if (vl-catch-all-error-p result)
       (progn
         (princ (strcat "\n    DXF WBLOCK 오류: " (vl-catch-all-error-message result)))
         (edwf:delete-file-safe temp-dwg)
         nil)
       (progn
         (setq docs     (vla-get-Documents (vlax-get-acad-object))
               temp-doc (vl-catch-all-apply 'vla-Open (list docs temp-dwg)))
         (if (vl-catch-all-error-p temp-doc)
           (progn
             (princ (strcat "\n    DXF 임시도면 열기 오류: " (vl-catch-all-error-message temp-doc)))
             (edwf:delete-file-safe temp-dwg)
             nil)
           (progn
             (setq result (vl-catch-all-apply 'vla-SaveAs (list temp-doc filepath save-type)))
             (vl-catch-all-apply 'vla-Close (list temp-doc :vlax-false))
             (edwf:delete-file-safe temp-dwg)
             (vla-Activate doc)
             (if (vl-catch-all-error-p result)
               (progn
                 (princ (strcat "\n    DXF 저장 오류: " (vl-catch-all-error-message result)))
                 nil)
               (if (findfile filepath)
                 (progn (princ " OK") T)
                 (progn (princ " FAIL") nil))))))))))

;;; ============================================================
;;; 섹션 12: 내보내기 실행
;;; ============================================================

(defun edwf:run-export-target (doc sheet-idx job-idx total-jobs
                                   pt-min pt-max folder prefix target
                                   / layout engine plotter ext fpath)
  (setq layout  (vla-get-activelayout doc)
        engine  (edwf:target-engine target)
        plotter (edwf:target-plotter target)
        ext     (edwf:target-ext target)
        fpath   (strcat folder "\\" prefix (itoa sheet-idx) ext))
  (princ (strcat "\n  [" (itoa job-idx) "/"
                 (itoa total-jobs) "] "
                 prefix (itoa sheet-idx) ext))
  (cond
    ((= engine "DXF")
     (edwf:export-dxf pt-min pt-max fpath doc))
    (T
     (edwf:plot-one pt-min pt-max fpath plotter doc layout))))

(defun edwf:run-export (doc / borders sorted targets total-jobs
                              sheet-idx job-idx ok-cnt fail-cnt
                              pt-min pt-max result
                              folder prefix plot-window)
  (setq borders (edwf:detect doc))

  (if (or (null borders) (= (length borders) 0))
    (princ "\n[오류] 테두리 없음. 레이어명 / ACI / 최소 크기 확인.")
    (progn
      (princ (strcat "\n  " (itoa (length borders)) "개 감지. 정렬 중..."))
      (setq sorted (edwf:sort borders))
      (setq targets (edwf:format-targets))
      (setq total-jobs (* (length sorted) (length targets)))

      (setq folder  (edwf:g "folder")
            prefix  (edwf:g "prefix"))

      (edwf:ensure-dir folder)

      (setq sheet-idx 1
            job-idx  1
            ok-cnt   0
            fail-cnt 0)

      (foreach bd sorted
        (setq plot-window (edwf:get-output-window bd)
              pt-min (car  plot-window)
              pt-max (cadr plot-window))
        (foreach target targets
          (setq result
            (edwf:run-export-target
              doc sheet-idx job-idx total-jobs
              pt-min pt-max folder prefix target))
          (if result
            (setq ok-cnt (1+ ok-cnt))
            (setq fail-cnt (1+ fail-cnt)))
          (setq job-idx (1+ job-idx)))
        (setq sheet-idx (1+ sheet-idx)))

      (princ "\n\n================================================")
      (princ (strcat "\n  성공: " (itoa ok-cnt) "개"))
      (if (> fail-cnt 0)
        (princ (strcat "\n  실패: " (itoa fail-cnt) "개")))
      (princ (strcat "\n  위치: " folder))
      (princ "\n================================================\n"))))

;;; ============================================================
;;; 섹션 13: 텍스트 모드
;;; ============================================================

(defun edwf:textmode (doc / mode fmt folder tmp-aci)
  (princ "\n[텍스트 모드]\n")

  (initget "Sample Layer")
  (setq mode (getkword "\n감지 [Sample 클릭/Layer 이름] <Sample>: "))
  (if (null mode) (setq mode "Sample"))

  (if (= mode "Sample")
    (edwf:pick-sample)
    (progn
      (edwf:s "layer" (getstring T "\n레이어명: "))
      (setq tmp-aci (getint "\nACI 번호 (0=전체): "))
      (edwf:s "aci" (if tmp-aci tmp-aci 0))))

  (initget "DXF PDF DWF DxfPdf PdfDwf DxfDwf All")
  (setq fmt (getkword "\n형식 [DXF/PDF/DWF/DxfPdf/PdfDwf/DxfDwf/All] <DXF>: "))
  (cond
    ((= fmt "PDF")    (edwf:apply-format "PDF"))
    ((= fmt "DWF")    (edwf:apply-format "DWF"))
    ((= fmt "DxfPdf") (edwf:apply-format "DXFPDF"))
    ((= fmt "PdfDwf") (edwf:apply-format "PDFDWF"))
    ((= fmt "DxfDwf") (edwf:apply-format "DXFDWF"))
    ((= fmt "All")    (edwf:apply-format "ALL"))
    (T                (edwf:apply-format "DXF")))

  (initget "Border Content")
  (if (= (getkword "\n출력 범위 [Border/Content] <Border>: ") "Content")
    (edwf:s "crop-mode" "content")
    (edwf:s "crop-mode" "border"))

  (setq folder
    (getstring T (strcat "\n폴더 [" (edwf:g "folder") "]: ")))
  (if (and folder (/= folder ""))
    (edwf:s "folder" folder))

  (edwf:run-export doc))

;;; ============================================================
(princ "\n================================================")
(princ "\n  export_dwf_main.lsp v5")
(princ (strcat "\n  AutoCAD R" (itoa (edwf:acad-ver))))
(princ (strcat "\n  엔진: "
  (if (>= (edwf:acad-ver) 21)
    "PDF/DWF는 ActiveX (실패 시 -PLOT 자동 폴백) / DXF는 WBLOCK + SaveAs"
    "PDF/DWF는 -PLOT / DXF는 WBLOCK + SaveAs")))
(princ "\n  명령: EXPORT-SMART")
(princ "\n================================================")
(princ)
