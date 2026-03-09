;;; ============================================================
;;; export_dwf_by_border.lsp  v3
;;;
;;; 기능: 색상/샘플 기반으로 테두리 감지 → 개별 DWF/PDF 내보내기
;;;       INSERT(블록참조) + LWPOLYLINE 모두 지원
;;;
;;; 플롯 방식: _.-PLOT 명령 (버전 호환, 페이지 설정 미변경)
;;; 사용법: APPLOAD → EXPORT-DWF-BORDERS
;;; ============================================================

(vl-load-com)

;;; ── 설정 (연관 리스트 1개로 관리) ────────────────────────────
(setq *dwfbdr:cfg* nil)

(defun dwfbdr:init (doc)
  (setq *dwfbdr:cfg*
    (list
      (cons "mode"       "sample")
      (cons "color-type" "aci")
      (cons "aci"        1)
      (cons "rgb-r"      255)  (cons "rgb-g" 0)  (cons "rgb-b" 0)
      (cons "sample-c"   nil)
      (cons "sample-lyr" nil)
      (cons "ent-type"   "BOTH")     ; "INSERT", "LWPOLYLINE", "BOTH"
      (cons "closed"     T)
      (cons "lyr-match"  nil)
      (cons "min-size"   100)
      (cons "folder"     (vl-filename-directory (vla-get-fullname doc)))
      (cons "prefix"     "도면")
      (cons "format"     "DWF")      ; "DWF" 또는 "PDF"
      (cons "plotter"    "DWF6 ePlot.pc3"))))

(defun dwfbdr:g (k) (cdr (assoc k *dwfbdr:cfg*)))
(defun dwfbdr:s (k v / p)
  (setq p (assoc k *dwfbdr:cfg*))
  (if p (setq *dwfbdr:cfg* (subst (cons k v) p *dwfbdr:cfg*))
        (setq *dwfbdr:cfg* (cons (cons k v) *dwfbdr:cfg*))))


;;; ── 메인 명령 ────────────────────────────────────────────────
(defun c:EXPORT-DWF-BORDERS ( / acad doc dcl-file dcl-id dlg-result)
  (setq acad (vlax-get-acad-object))
  (setq doc  (vla-get-activedocument acad))
  (dwfbdr:init doc)

  (princ "\n========================================")
  (princ "\n  DWF/PDF 일괄 내보내기 - 테두리 감지")
  (princ "\n========================================")

  ;; DCL 파일 탐색
  (setq dcl-file (findfile "export_dwf_border_ui.dcl"))
  (if (null dcl-file)
    (progn
      (setq dcl-file
        (strcat (vl-filename-directory
                  (findfile "export_dwf_by_border.lsp"))
                "\\export_dwf_border_ui.dcl"))
      (if (not (findfile dcl-file)) (setq dcl-file nil))))

  ;; DCL 없으면 텍스트 모드
  (if (null dcl-file)
    (progn (dwfbdr:textmode doc) (exit)))

  (setq dcl-id (load_dialog dcl-file))
  (if (< dcl-id 0)
    (progn (dwfbdr:textmode doc) (exit)))

  (if (not (new_dialog "dwf_border_dialog" dcl-id))
    (progn (unload_dialog dcl-id) (exit)))

  (dwfbdr:setup-dlg)
  (setq dlg-result (start_dialog))

  ;; 샘플 선택 루프
  (while (= dlg-result 2)
    (dwfbdr:pick-sample)
    (if (not (new_dialog "dwf_border_dialog" dcl-id))
      (progn (unload_dialog dcl-id) (exit)))
    (dwfbdr:setup-dlg)
    (dwfbdr:show-sample)
    (setq dlg-result (start_dialog)))

  (unload_dialog dcl-id)
  (if (/= dlg-result 1) (progn (princ "\n취소.") (exit)))

  ;; 실행
  (dwfbdr:run-export doc)
  (princ))


;;; ── DCL 콜백 설정 (1회 정의) ─────────────────────────────────
(defun dwfbdr:setup-dlg ()
  (set_tile "ed_folder"   (dwfbdr:g "folder"))
  (set_tile "ed_prefix"   (dwfbdr:g "prefix"))
  (set_tile "ed_plotter"  (dwfbdr:g "plotter"))
  (set_tile "ed_min_size" (itoa (dwfbdr:g "min-size")))
  (set_tile "ed_aci"      (itoa (dwfbdr:g "aci")))
  (set_tile "ed_r"        (itoa (dwfbdr:g "rgb-r")))
  (set_tile "ed_g"        (itoa (dwfbdr:g "rgb-g")))
  (set_tile "ed_b"        (itoa (dwfbdr:g "rgb-b")))

  ;; 모드
  (action_tile "rb_sample" "(dwfbdr:s \"mode\" \"sample\")")
  (action_tile "rb_manual" "(dwfbdr:s \"mode\" \"manual\")")
  (action_tile "rb_aci"    "(dwfbdr:s \"color-type\" \"aci\")")
  (action_tile "rb_rgb"    "(dwfbdr:s \"color-type\" \"rgb\")")
  ;; 출력 형식
  (action_tile "rb_dwf"
    "(dwfbdr:s \"format\" \"DWF\")(dwfbdr:s \"plotter\" \"DWF6 ePlot.pc3\")(set_tile \"ed_plotter\" \"DWF6 ePlot.pc3\")")
  (action_tile "rb_pdf"
    "(dwfbdr:s \"format\" \"PDF\")(dwfbdr:s \"plotter\" \"DWG To PDF.pc3\")(set_tile \"ed_plotter\" \"DWG To PDF.pc3\")")
  ;; 버튼
  (action_tile "btn_pick"    "(done_dialog 2)")
  (action_tile "btn_browse"  "(dwfbdr:browse)")
  (action_tile "btn_preview" "(dwfbdr:preview)")
  ;; 입력
  (action_tile "ed_aci"      "(dwfbdr:s \"aci\" (atoi $value))")
  (action_tile "ed_r"        "(dwfbdr:s \"rgb-r\" (atoi $value))")
  (action_tile "ed_g"        "(dwfbdr:s \"rgb-g\" (atoi $value))")
  (action_tile "ed_b"        "(dwfbdr:s \"rgb-b\" (atoi $value))")
  (action_tile "ed_folder"   "(dwfbdr:s \"folder\" $value)")
  (action_tile "ed_prefix"   "(dwfbdr:s \"prefix\" $value)")
  (action_tile "ed_plotter"  "(dwfbdr:s \"plotter\" $value)")
  (action_tile "ed_min_size" "(dwfbdr:s \"min-size\" (atoi $value))")
  (action_tile "chk_closed"  "(dwfbdr:s \"closed\" (= $value \"1\"))")
  (action_tile "chk_layer_match" "(dwfbdr:s \"lyr-match\" (= $value \"1\"))")
  ;; 확인/취소
  (action_tile "accept" "(dwfbdr:save-dlg)(done_dialog 1)")
  (action_tile "cancel" "(done_dialog 0)"))

(defun dwfbdr:save-dlg ()
  (dwfbdr:s "folder"   (get_tile "ed_folder"))
  (dwfbdr:s "prefix"   (get_tile "ed_prefix"))
  (dwfbdr:s "plotter"  (get_tile "ed_plotter"))
  (dwfbdr:s "min-size" (atoi (get_tile "ed_min_size")))
  (dwfbdr:s "aci"      (atoi (get_tile "ed_aci")))
  (dwfbdr:s "rgb-r"    (atoi (get_tile "ed_r")))
  (dwfbdr:s "rgb-g"    (atoi (get_tile "ed_g")))
  (dwfbdr:s "rgb-b"    (atoi (get_tile "ed_b"))))

(defun dwfbdr:show-sample ( / sc)
  (setq sc (dwfbdr:g "sample-c"))
  (if sc (progn
    (set_tile "txt_sample_info" "✔ 샘플 선택됨")
    (set_tile "txt_detected_color"
      (if (listp sc)
        (strcat "RGB(" (itoa (car sc)) ","
                (itoa (cadr sc)) "," (itoa (caddr sc)) ")")
        (strcat "ACI " (itoa sc))))
    (set_tile "txt_detected_layer"
      (if (dwfbdr:g "sample-lyr") (dwfbdr:g "sample-lyr") "-")))))


;;; ── 폴더 찾아보기 ────────────────────────────────────────────
(defun dwfbdr:browse ( / shell fo fp)
  (setq shell (vlax-create-object "Shell.Application"))
  (if shell (progn
    (setq fo (vlax-invoke-method shell 'BrowseForFolder
               0 "폴더 선택" 0 ""))
    (if fo (progn
      (setq fp (vlax-get-property
                 (vlax-get-property fo 'Self) 'Path))
      (if (= (substr fp (strlen fp)) "\\")
        (setq fp (substr fp 1 (1- (strlen fp)))))
      (dwfbdr:s "folder" fp)
      (set_tile "ed_folder" fp)))
    (vlax-release-object shell))))


;;; ── 미리보기 ─────────────────────────────────────────────────
(defun dwfbdr:preview ( / doc bds n)
  (setq doc (vla-get-activedocument (vlax-get-acad-object)))
  (setq bds (dwfbdr:detect doc))
  (setq n (if bds (length bds) 0))
  (set_tile "txt_count" (strcat "감지: " (itoa n) "개")))


;;; ── 샘플 선택 ────────────────────────────────────────────────
(defun dwfbdr:pick-sample ( / ent obj lyr tc cv r g b dxf-c)
  (princ "\n테두리를 클릭하세요...")
  (setq ent (car (entsel "\n선택: ")))
  (if (null ent)
    (princ "\n  취소됨.")
    (progn
      (setq obj (vlax-ename->vla-object ent))
      (setq lyr (vla-get-layer obj))
      (dwfbdr:s "sample-lyr" lyr)

      ;; 엔티티 타입 감지
      (dwfbdr:s "ent-type"
        (if (= (cdr (assoc 0 (entget ent))) "INSERT")
          "INSERT" "LWPOLYLINE"))

      ;; 색상 추출
      (setq tc (vl-catch-all-apply 'vla-get-truecolor (list obj)))
      (if (and (not (vl-catch-all-error-p tc)) tc)
        (progn
          (setq r (vla-get-red tc) g (vla-get-green tc) b (vla-get-blue tc))
          (setq cv (vl-catch-all-apply 'vla-get-color (list obj)))
          (if (and (not (vl-catch-all-error-p cv))
                   (numberp cv) (/= cv 256))
            (progn (dwfbdr:s "sample-c" cv)
                   (dwfbdr:s "color-type" "aci") (dwfbdr:s "aci" cv)
                   (princ (strcat "\n  ACI " (itoa cv))))
            (progn (dwfbdr:s "sample-c" (list r g b))
                   (dwfbdr:s "color-type" "rgb")
                   (dwfbdr:s "rgb-r" r) (dwfbdr:s "rgb-g" g) (dwfbdr:s "rgb-b" b)
                   (princ (strcat "\n  RGB(" (itoa r) "," (itoa g) "," (itoa b) ")")))))
        (progn
          (setq dxf-c (cdr (assoc 62 (entget ent))))
          (if dxf-c
            (progn (dwfbdr:s "sample-c" dxf-c)
                   (dwfbdr:s "color-type" "aci") (dwfbdr:s "aci" dxf-c))
            (dwfbdr:s "sample-c" 256))))
      (princ (strcat "\n  레이어: " lyr)))))


;;; ── 테두리 감지 (INSERT + LWPOLYLINE 지원) ──────────────────
(defun dwfbdr:detect (doc / ss-all borders i ent obj
                           pt-min pt-max match-p
                           filter1 filter2 tc r g b sc min-sz et)
  (setq borders '())
  (setq min-sz (dwfbdr:g "min-size"))
  (setq sc (dwfbdr:g "sample-c"))
  (setq et (dwfbdr:g "ent-type"))

  ;; 엔티티 타입별 필터 구성
  (setq filter1 nil filter2 nil)

  ;; INSERT 필터
  (if (or (= et "INSERT") (= et "BOTH"))
    (progn
      (setq filter1 '((0 . "INSERT")))
      (if (and (dwfbdr:g "lyr-match") (dwfbdr:g "sample-lyr"))
        (setq filter1 (append filter1
          (list (cons 8 (dwfbdr:g "sample-lyr"))))))
      ;; ACI 필터 (INSERT에도 적용 가능)
      (if (and (or (and (= (dwfbdr:g "mode") "sample") (numberp sc) (/= sc 256))
               (and (= (dwfbdr:g "mode") "manual") (= (dwfbdr:g "color-type") "aci")))
        (setq filter1 (append filter1
          (list (cons 62 (if (= (dwfbdr:g "mode") "sample") sc (dwfbdr:g "aci")))))))))

  ;; LWPOLYLINE 필터
  (if (or (= et "LWPOLYLINE") (= et "BOTH"))
    (progn
      (setq filter2 '((0 . "LWPOLYLINE")))
      (if (dwfbdr:g "closed")
        (setq filter2 (append filter2 '((70 . 1)))))
      (if (and (dwfbdr:g "lyr-match") (dwfbdr:g "sample-lyr"))
        (setq filter2 (append filter2
          (list (cons 8 (dwfbdr:g "sample-lyr"))))))
      (if (and (or (and (= (dwfbdr:g "mode") "sample") (numberp sc) (/= sc 256))
               (and (= (dwfbdr:g "mode") "manual") (= (dwfbdr:g "color-type") "aci")))
        (setq filter2 (append filter2
          (list (cons 62 (if (= (dwfbdr:g "mode") "sample") sc (dwfbdr:g "aci")))))))))

  ;; 선택 세트 수집 + BoundingBox 추출
  (foreach flt (list filter1 filter2)
    (if flt
      (progn
        (setq ss-all (ssget "X" flt))
        (if ss-all
          (progn
            (setq i 0)
            (repeat (sslength ss-all)
              (setq ent (ssname ss-all i))
              (setq obj (vlax-ename->vla-object ent))
              (setq match-p T)

              ;; RGB 후처리
              (if (and match-p
                       (or (and (= (dwfbdr:g "mode") "sample") (listp sc))
                           (and (= (dwfbdr:g "mode") "manual")
                                (= (dwfbdr:g "color-type") "rgb"))))
                (progn
                  (setq tc (vl-catch-all-apply 'vla-get-truecolor (list obj)))
                  (if (not (vl-catch-all-error-p tc))
                    (progn
                      (setq r (vla-get-red tc) g (vla-get-green tc) b (vla-get-blue tc))
                      (if (= (dwfbdr:g "mode") "sample")
                        (if (not (and (= r (car sc)) (= g (cadr sc)) (= b (caddr sc))))
                          (setq match-p nil))
                        (if (not (and (= r (dwfbdr:g "rgb-r"))
                                      (= g (dwfbdr:g "rgb-g"))
                                      (= b (dwfbdr:g "rgb-b"))))
                          (setq match-p nil))))
                    (setq match-p nil))))

              ;; BoundingBox
              (if match-p
                (if (not (vl-catch-all-error-p
                           (vl-catch-all-apply 'vla-getboundingbox
                             (list obj 'pt-min 'pt-max))))
                  (progn
                    (setq pt-min (vlax-safearray->list pt-min))
                    (setq pt-max (vlax-safearray->list pt-max))
                    (if (and (> (- (car pt-max) (car pt-min)) min-sz)
                             (> (- (cadr pt-max) (cadr pt-min)) min-sz))
                      (setq borders (cons (list pt-min pt-max) borders))))))

              (setq i (1+ i))))))))
  borders)


;;; ── 정렬 ─────────────────────────────────────────────────────
(defun dwfbdr:sort (borders / hs ah thr)
  (if (null borders) nil
    (progn
      (setq hs '())
      (foreach b borders
        (setq hs (cons (abs (- (cadr (cadr b)) (cadr (car b)))) hs)))
      (setq ah (/ (apply '+ hs) (float (length hs))))
      (setq thr (* 0.4 ah))
      (vl-sort borders
        (function
          (lambda (a b / ay by ax bx)
            (setq ay (cadr (cadr a)) by (cadr (cadr b)))
            (setq ax (car (car a))   bx (car (car b)))
            (if (> (abs (- ay by)) thr) (> ay by) (< ax bx))))))))


;;; ── 플롯: _.-PLOT 명령 ──────────────────────────────────────
(defun dwfbdr:plot (pt-min pt-max filepath plotter
                     / old-ce old-bg old-fd old-err
                       x1s y1s x2s y2s plot-ok)
  (setq old-err *error* plot-ok T)
  (defun *error* (msg)
    (setq plot-ok nil)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\n    ✘ " msg)))
    (setvar "CMDECHO" old-ce)
    (setvar "BACKGROUNDPLOT" old-bg)
    (setvar "FILEDIA" old-fd)
    (setq *error* old-err))

  (setq old-ce (getvar "CMDECHO")
        old-bg (getvar "BACKGROUNDPLOT")
        old-fd (getvar "FILEDIA"))
  (setvar "CMDECHO" 0) (setvar "BACKGROUNDPLOT" 0) (setvar "FILEDIA" 0)
  (while (> (getvar "CMDACTIVE") 0) (command ""))

  (setq x1s (rtos (car pt-min) 2 6) y1s (rtos (cadr pt-min) 2 6)
        x2s (rtos (car pt-max) 2 6) y2s (rtos (cadr pt-max) 2 6))

  (command "_.-PLOT"
    "_Yes" "" plotter "" "_Millimeters" "_Landscape" "_No"
    "_Window" (strcat x1s "," y1s) (strcat x2s "," y2s)
    "_Fit" "0,0" "_Yes" "." "_Yes" "_No"
    filepath "_No" "_Yes")

  (setvar "CMDECHO" old-ce)
  (setvar "BACKGROUNDPLOT" old-bg)
  (setvar "FILEDIA" old-fd)
  (setq *error* old-err)

  (if plot-ok
    (if (findfile filepath)
      (progn (princ " ✔") T)
      (progn (princ " ✘") nil))
    nil))


;;; ── 내보내기 실행 ────────────────────────────────────────────
(defun dwfbdr:run-export (doc / borders sorted cnt ok fail
                               pt-min pt-max fpath folder
                               prefix plotter ext result)
  (setq borders (dwfbdr:detect doc))
  (if (or (null borders) (= (length borders) 0))
    (princ "\n[오류] 테두리를 찾을 수 없습니다.")
    (progn
      (princ (strcat "\n  " (itoa (length borders)) "개 감지."))
      (setq sorted (dwfbdr:sort borders))
      (setq folder  (dwfbdr:g "folder")
            prefix  (dwfbdr:g "prefix")
            plotter (dwfbdr:g "plotter")
            ext     (if (= (dwfbdr:g "format") "PDF") ".pdf" ".dwf"))

      (if (not (vl-file-directory-p folder))
        (progn (vl-mkdir folder)
               (princ (strcat "\n  폴더 생성: " folder))))

      (setq cnt 1 ok 0 fail 0)
      (foreach bd sorted
        (setq pt-min (car bd) pt-max (cadr bd))
        (setq fpath (strcat folder "\\" prefix (itoa cnt) ext))
        (princ (strcat "\n  [" (itoa cnt) "/"
          (itoa (length sorted)) "] " prefix (itoa cnt) ext))
        (setq result (dwfbdr:plot pt-min pt-max fpath plotter))
        (if result (setq ok (1+ ok)) (setq fail (1+ fail)))
        (setq cnt (1+ cnt)))

      (princ "\n\n========================================")
      (princ (strcat "\n  ✔ 성공: " (itoa ok) "개"))
      (if (> fail 0) (princ (strcat "\n  ✘ 실패: " (itoa fail) "개")))
      (princ (strcat "\n  위치: " folder))
      (princ "\n========================================"))))


;;; ── 텍스트 모드 ──────────────────────────────────────────────
(defun dwfbdr:textmode (doc / mode aci-val fmt folder)
  (princ "\n[텍스트 모드]\n")

  (initget "Sample Manual")
  (setq mode (getkword "\n감지 [Sample/Manual] <Sample>: "))
  (if (null mode) (setq mode "Sample"))
  (cond
    ((= mode "Sample") (dwfbdr:pick-sample))
    ((= mode "Manual")
     (setq aci-val (getint "\nACI 번호 (1=빨강): "))
     (if aci-val (progn
       (dwfbdr:s "aci" aci-val) (dwfbdr:s "mode" "manual")
       (dwfbdr:s "color-type" "aci")))))

  (initget "DWF PDF")
  (setq fmt (getkword "\n형식 [DWF/PDF] <DWF>: "))
  (if (= fmt "PDF")
    (progn (dwfbdr:s "format" "PDF")
           (dwfbdr:s "plotter" "DWG To PDF.pc3"))
    (progn (dwfbdr:s "format" "DWF")
           (dwfbdr:s "plotter" "DWF6 ePlot.pc3")))

  (setq folder (getstring T
    (strcat "\n폴더 [" (dwfbdr:g "folder") "]: ")))
  (if (and folder (/= folder ""))
    (dwfbdr:s "folder" folder))

  (dwfbdr:run-export doc))


(princ "\n[export_dwf_by_border.lsp v3 로드]")
(princ "\n  명령: EXPORT-DWF-BORDERS  |  DWF/PDF, INSERT+폴리라인")
(princ)
