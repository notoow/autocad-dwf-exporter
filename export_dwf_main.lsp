;;; ============================================================
;;; export_dwf_main.lsp  v5
;;;
;;; 기능: 모델 공간의 블록참조(INSERT) 또는 폴리라인 테두리를
;;;       감지하여 각각 DWF 또는 PDF 로 일괄 내보내기
;;;
;;; 지원: AutoCAD 2015 ~ 2025 (R19 ~ R25), 한/영 모두 동작
;;;
;;; 파일 구성 (같은 폴더에 위치):
;;;   - export_dwf_main.lsp  (이 파일)
;;;   - export_dwf_ui.dcl    (다이얼로그)
;;;
;;; 사용법: APPLOAD → export_dwf_main.lsp → 명령: EXPORT-DWF
;;;
;;; 플롯 엔진 (버전 자동 선택):
;;;   R21+(2016~): ActiveX PlotToFile  → 실패 시 -PLOT 자동 폴백
;;;   R20-(2015) : -PLOT 명령
;;; ============================================================

(vl-load-com)

;;; 로드 시점(APPLOAD 중)에 이 파일의 폴더 경로를 전역변수로 저장
;;; APPLOAD 실행 중에는 findfile이 이 파일을 찾을 수 있음
(setq *edwf:dir*
  (if (findfile "export_dwf_main.lsp")
    (vl-filename-directory (findfile "export_dwf_main.lsp"))
    ""))

;;; ============================================================
;;; 섹션 1: 설정 관리
;;; ============================================================

(setq *edwf:cfg* nil)

(defun edwf:init (doc / fp)
  (setq fp (vla-get-fullname doc))
  (setq *edwf:cfg*
    (list
      (cons "mode"       "sample")
      (cons "layer"      "")
      (cons "aci"        0)
      (cons "format"     "DWF")
      (cons "plotter"    "DWF6 ePlot.pc3")
      (cons "ext"        ".dwf")
      (cons "folder"     (if (and fp (/= fp ""))
                           (vl-filename-directory fp)
                           "C:\\Temp"))
      (cons "prefix"     "도면")
      (cons "minsize"    500)
      (cons "sample-lyr" nil)
      (cons "sample-aci" nil))))

(defun edwf:g (k)   (cdr (assoc k *edwf:cfg*)))
(defun edwf:s (k v / p)
  (setq p (assoc k *edwf:cfg*))
  (if p
    (setq *edwf:cfg* (subst (cons k v) p *edwf:cfg*))
    (setq *edwf:cfg* (cons  (cons k v)   *edwf:cfg*))))

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

(defun c:EXPORT-DWF ( / acad doc dcl-file dcl-id dlg-result)

  (setq acad (vlax-get-acad-object))
  (setq doc  (vla-get-activedocument acad))
  (edwf:init doc)

  (princ "\n================================================")
  (princ "\n  DWF/PDF 일괄 내보내기  v5")
  (princ (strcat "\n  AutoCAD R" (itoa (edwf:acad-ver))))
  (princ (strcat "\n  엔진: "
    (if (>= (edwf:acad-ver) 21)
      "ActiveX (+ -PLOT 폴백)"
      "-PLOT 명령")))
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

;;; ============================================================
;;; 섹션 5: DCL 파일 탐색
;;; ============================================================

(defun edwf:find-dcl ( / candidates result)
  ;; *edwf:dir* = 로드 시점에 저장된 이 LSP 파일의 폴더
  ;; → 어떤 경로에 설치해도 DCL을 자동으로 찾음
  (setq result nil)
  (setq candidates
    (list
      (if (and *edwf:dir* (/= *edwf:dir* ""))
        (strcat *edwf:dir* "\\export_dwf_ui.dcl"))
      (findfile "export_dwf_ui.dcl")
      (strcat (edwf:g "folder") "\\export_dwf_ui.dcl")))
  (foreach c candidates
    (if (and (null result) c (vl-file-exists-p c))
      (setq result c)))
  result)

;;; ============================================================
;;; 섹션 6: 다이얼로그
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
            (setq dlg-result (start_dialog)))))
      dlg-result)))

(defun edwf:dlg-init ()
  (set_tile "ed_layer"   (if (edwf:g "layer") (edwf:g "layer") ""))
  (set_tile "ed_aci"     (if (> (edwf:g "aci") 0)
                           (itoa (edwf:g "aci")) ""))
  (set_tile "ed_folder"  (edwf:g "folder"))
  (set_tile "ed_prefix"  (edwf:g "prefix"))
  (set_tile "ed_minsize" (itoa (edwf:g "minsize")))
  (set_tile "txt_count"  "감지된 개수: -"))

(defun edwf:dlg-callbacks ()
  (action_tile "rb_sample" "(edwf:s \"mode\" \"sample\")")
  (action_tile "rb_layer"  "(edwf:s \"mode\" \"layer\")")
  (action_tile "btn_pick"  "(done_dialog 2)")

  (action_tile "rb_dwf"
    (strcat "(edwf:s \"format\" \"DWF\")"
            "(edwf:s \"plotter\" \"DWF6 ePlot.pc3\")"
            "(edwf:s \"ext\" \".dwf\")"))
  (action_tile "rb_pdf"
    (strcat "(edwf:s \"format\" \"PDF\")"
            "(edwf:s \"plotter\" \"DWG To PDF.pc3\")"
            "(edwf:s \"ext\" \".pdf\")"))

  (action_tile "btn_browse"  "(edwf:browse-folder)")
  (action_tile "btn_preview" "(edwf:dlg-save)(edwf:dlg-preview)")

  (action_tile "ed_layer"   "(edwf:s \"layer\"   $value)")
  (action_tile "ed_aci"
    "(edwf:s \"aci\" (if (= $value \"\") 0 (atoi $value)))")
  (action_tile "ed_folder"  "(edwf:s \"folder\"  $value)")
  (action_tile "ed_prefix"  "(edwf:s \"prefix\"  $value)")
  (action_tile "ed_minsize"
    "(edwf:s \"minsize\" (if (= $value \"\") 500 (atoi $value)))")

  (action_tile "accept" "(edwf:dlg-save)(done_dialog 1)")
  (action_tile "cancel" "(done_dialog 0)"))

(defun edwf:dlg-save ( / tmp-min tmp-aci)
  (edwf:s "layer"  (get_tile "ed_layer"))
  (edwf:s "folder" (get_tile "ed_folder"))
  (edwf:s "prefix" (get_tile "ed_prefix"))
  (setq tmp-min (atoi (get_tile "ed_minsize")))
  (edwf:s "minsize" (if (> tmp-min 0) tmp-min 500))
  (setq tmp-aci (get_tile "ed_aci"))
  (edwf:s "aci" (if (or (null tmp-aci) (= tmp-aci "")) 0 (atoi tmp-aci))))

(defun edwf:dlg-preview ( / doc bds)
  (setq doc (vla-get-activedocument (vlax-get-acad-object)))
  (setq bds (edwf:detect doc))
  (set_tile "txt_count"
    (strcat "감지된 개수: " (itoa (if bds (length bds) 0)) "개")))

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
      (vlax-release-object shell))))

;;; ============================================================
;;; 섹션 7: 샘플 선택
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
;;; 섹션 8: 테두리 감지
;;; ============================================================

(defun edwf:detect (doc / ss flt-i flt-p
                         i ent obj pt-min pt-max
                         borders minsize lyr aci)
  (setq borders nil
        minsize (edwf:g "minsize")
        lyr     (edwf:g "layer")
        aci     (edwf:g "aci"))

  ;; INSERT 필터
  (setq flt-i (list '(0 . "INSERT")))
  (if (and lyr (/= lyr ""))
    (setq flt-i (append flt-i (list (cons 8 lyr)))))
  (if (and aci (> aci 0) (< aci 256))
    (setq flt-i (append flt-i (list (cons 62 aci)))))

  ;; LWPOLYLINE 필터 (닫힌 것만)
  (setq flt-p (list '(0 . "LWPOLYLINE") '(70 . 1)))
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
          (if (not (vl-catch-all-error-p
                     (vl-catch-all-apply
                       'vla-getboundingbox
                       (list obj 'pt-min 'pt-max))))
            (progn
              (setq pt-min (vlax-safearray->list pt-min)
                    pt-max (vlax-safearray->list pt-max))
              (if (and
                    (> (- (car  pt-max) (car  pt-min)) minsize)
                    (> (- (cadr pt-max) (cadr pt-min)) minsize))
                (if (not (edwf:bbox-dup-p borders pt-min pt-max))
                  (setq borders (cons (list pt-min pt-max) borders))))))
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

;;; ============================================================
;;; 섹션 9: 정렬
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
;;; 섹션 10: 플롯 엔진
;;; ============================================================

(defun edwf:plot-one (pt-min pt-max filepath plotter doc layout)
  (if (>= (edwf:acad-ver) 21)
    (edwf:plot-activex pt-min pt-max filepath plotter doc layout)
    (edwf:plot-command pt-min pt-max filepath plotter)))

;;; ── 방법 A: ActiveX (R21+) ─────────────────────────────────
(defun edwf:plot-activex (pt-min pt-max filepath plotter
                           doc layout
                           / plot-obj win-min win-max
                             old-cfg old-ptype old-ustd
                             old-scale old-rot old-center
                             old-bgplot old-err
                             result fallback-p)

  (setq fallback-p nil)
  (setq old-bgplot (getvar "BACKGROUNDPLOT"))
  (setvar "BACKGROUNDPLOT" 0)

  ;; 레이아웃 백업 (error 등록 전에 완료)
  (setq old-cfg    (vl-catch-all-apply 'vla-get-ConfigName       (list layout))
        old-ptype  (vl-catch-all-apply 'vla-get-PlotType         (list layout))
        old-ustd   (vl-catch-all-apply 'vla-get-UseStandardScale (list layout))
        old-scale  (vl-catch-all-apply 'vla-get-StandardScale    (list layout))
        old-rot    (vl-catch-all-apply 'vla-get-PlotRotation     (list layout))
        old-center (vl-catch-all-apply 'vla-get-CenterPlot       (list layout)))

  ;; *error* 등록
  (setq old-err *error*)
  (defun *error* (msg)
    (edwf:restore-layout layout
      old-cfg old-ptype old-ustd old-scale old-rot old-center)
    (setvar "BACKGROUNDPLOT" old-bgplot)
    (setq *error* old-err)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\n    ActiveX 오류: " msg))))

  ;; 플롯 설정 적용
  (vl-catch-all-apply 'vla-put-ConfigName       (list layout plotter))
  (vl-catch-all-apply 'vla-put-PlotType         (list layout 4))
  (vl-catch-all-apply 'vla-put-UseStandardScale (list layout :vlax-true))
  (vl-catch-all-apply 'vla-put-StandardScale    (list layout 0))
  (vl-catch-all-apply 'vla-put-PlotRotation     (list layout 0))
  (vl-catch-all-apply 'vla-put-CenterPlot       (list layout :vlax-true))

  ;; 윈도우 영역
  (setq win-min (vlax-make-safearray vlax-vbDouble '(0 . 1))
        win-max (vlax-make-safearray vlax-vbDouble '(0 . 1)))
  (vlax-safearray-put-element win-min 0 (car  pt-min))
  (vlax-safearray-put-element win-min 1 (cadr pt-min))
  (vlax-safearray-put-element win-max 0 (car  pt-max))
  (vlax-safearray-put-element win-max 1 (cadr pt-max))
  (vl-catch-all-apply 'vla-SetWindowToPlot (list layout win-min win-max))

  ;; Plot 객체
  (setq plot-obj
    (vl-catch-all-apply 'vlax-get-property (list doc 'Plot)))

  ;; 실행
  (cond
    ((or (null plot-obj) (vl-catch-all-error-p plot-obj))
     (princ "\n    Plot 객체 실패 → -PLOT 폴백")
     (setq fallback-p T))
    (T
     (setq result
       (vl-catch-all-apply 'vla-PlotToFile (list plot-obj filepath)))
     (if (vl-catch-all-error-p result)
       (progn
         (princ (strcat "\n    PlotToFile 실패: "
                  (vl-catch-all-error-message result)
                  " → -PLOT 폴백"))
         (setq fallback-p T)))))

  ;; 복원
  (edwf:restore-layout layout
    old-cfg old-ptype old-ustd old-scale old-rot old-center)
  (setvar "BACKGROUNDPLOT" old-bgplot)
  (setq *error* old-err)

  ;; 결과
  (cond
    (fallback-p
     (edwf:plot-command pt-min pt-max filepath plotter))
    ((findfile filepath)
     (princ " OK") T)
    (T
     (princ " FAIL") nil)))

;;; ── 레이아웃 복원 헬퍼 ──────────────────────────────────────
(defun edwf:restore-layout (layout cfg ptype ustd scale rot center)
  (if (and cfg    (not (vl-catch-all-error-p cfg)))
    (vl-catch-all-apply 'vla-put-ConfigName       (list layout cfg)))
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
(defun edwf:plot-command (pt-min pt-max filepath plotter
                           / old-ce old-bg old-fd old-err
                             x1s y1s x2s y2s plot-ok)
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
        y2s (rtos (cadr pt-max) 2 4))

  (command
    "_.-PLOT"
    "_Yes"                          ; 상세 설정
    ""                              ; 현재 레이아웃
    plotter                         ; 플로터
    ""                              ; 용지 (현재 유지)
    ""                              ; 단위 (현재 유지)
    ""                              ; 방향 (현재 유지)
    "_No"                           ; 뒤집기
    "_Window"                       ; 영역
    (strcat x1s "," y1s)            ; 좌하단
    (strcat x2s "," y2s)            ; 우상단
    "_Fit"                          ; 스케일
    "0,0"                           ; 오프셋
    "_Yes"                          ; 플롯 스타일
    ""                              ; CTB (현재 유지)
    "_Yes"                          ; 선가중치
    "_No"                           ; 선가중치 스케일링
    "_Yes"                          ; 파일에 플롯 (가상 플로터 필수)
    filepath                        ; 파일 경로
    "_No"                           ; 설정 저장 안 함
    "_Yes"                          ; 진행
  )

  (setvar "CMDECHO"        old-ce)
  (setvar "BACKGROUNDPLOT" old-bg)
  (setvar "FILEDIA"        old-fd)
  (setq *error* old-err)

  (if plot-ok
    (if (findfile filepath)
      (progn (princ " OK") T)
      (progn (princ " FAIL (프롬프트 불일치 가능)") nil))
    nil))

;;; ============================================================
;;; 섹션 11: 내보내기 실행
;;; ============================================================

(defun edwf:run-export (doc / borders sorted layout
                              cnt ok-cnt fail-cnt
                              pt-min pt-max fpath result
                              folder prefix plotter ext)
  (setq borders (edwf:detect doc))

  (if (or (null borders) (= (length borders) 0))
    (princ "\n[오류] 테두리 없음. 레이어명 / ACI / 최소 크기 확인.")
    (progn
      (princ (strcat "\n  " (itoa (length borders)) "개 감지. 정렬 중..."))
      (setq sorted (edwf:sort borders))

      (setq folder  (edwf:g "folder")
            prefix  (edwf:g "prefix")
            plotter (edwf:g "plotter")
            ext     (edwf:g "ext"))

      (edwf:ensure-dir folder)

      (setq layout   (vla-get-activelayout doc)
            cnt      1
            ok-cnt   0
            fail-cnt 0)

      (foreach bd sorted
        (setq pt-min (car  bd)
              pt-max (cadr bd)
              fpath  (strcat folder "\\" prefix (itoa cnt) ext))
        (princ (strcat "\n  [" (itoa cnt) "/"
                       (itoa (length sorted)) "] "
                       prefix (itoa cnt) ext))
        (setq result
          (edwf:plot-one pt-min pt-max fpath plotter doc layout))
        (if result
          (setq ok-cnt (1+ ok-cnt))
          (setq fail-cnt (1+ fail-cnt)))
        (setq cnt (1+ cnt)))

      (princ "\n\n================================================")
      (princ (strcat "\n  성공: " (itoa ok-cnt) "개"))
      (if (> fail-cnt 0)
        (princ (strcat "\n  실패: " (itoa fail-cnt) "개")))
      (princ (strcat "\n  위치: " folder))
      (princ "\n================================================\n"))))

;;; ============================================================
;;; 섹션 12: 텍스트 모드
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

  (initget "DWF PDF")
  (setq fmt (getkword "\n형식 [DWF/PDF] <DWF>: "))
  (cond
    ((= fmt "PDF")
     (edwf:s "format" "PDF")
     (edwf:s "plotter" "DWG To PDF.pc3")
     (edwf:s "ext" ".pdf"))
    (T
     (edwf:s "format" "DWF")
     (edwf:s "plotter" "DWF6 ePlot.pc3")
     (edwf:s "ext" ".dwf")))

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
    "ActiveX (실패 시 -PLOT 자동 폴백)"
    "-PLOT 명령")))
(princ "\n  명령: EXPORT-DWF")
(princ "\n================================================")
(princ)
