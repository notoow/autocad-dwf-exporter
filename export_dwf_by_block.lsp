;;; ============================================================
;;; export_dwf_by_block.lsp  v3
;;;
;;; 기능: 선택한 레이어의 블록참조(INSERT)를 감지,
;;;       각 영역을 도면1.dwf/pdf 로 개별 플롯
;;;
;;; 플롯 방식: _.-PLOT 명령 (COM vla-PlotToFile 대신)
;;;   - AutoCAD 버전 호환성 확보
;;;   - 레이아웃 페이지 설정을 변경하지 않음
;;;   - _ 접두사로 한국어 AutoCAD에서도 동작
;;;
;;; 사용법: APPLOAD → EXPORT-DWF
;;; ============================================================

(vl-load-com)

;;; ── 메인 명령 ────────────────────────────────────────────────
(defun c:EXPORT-DWF ( / acad doc
                       target-layer fmt plotter-name file-ext
                       ss i ent obj pt-min pt-max
                       borders sorted-borders
                       dwf-folder dwf-path
                       cnt ok-cnt fail-cnt result)

  (setq acad (vlax-get-acad-object))
  (setq doc  (vla-get-activedocument acad))

  (princ "\n============================================")
  (princ "\n  DWF/PDF 일괄 내보내기 - 블록참조 기준")
  (princ "\n============================================")

  ;; ── 1. 레이어 선택 ────────────────────────────────────────
  (setq target-layer (dwfblk:select-layer doc))
  (if (null target-layer)
    (progn (princ "\n레이어 선택 취소.") (exit))
  )
  (princ (strcat "\n  레이어: " target-layer))

  ;; ── 2. 출력 형식 선택 ──────────────────────────────────────
  (initget "DWF PDF")
  (setq fmt (getkword "\n출력 형식 [DWF/PDF] <DWF>: "))
  (if (null fmt) (setq fmt "DWF"))

  (if (= fmt "PDF")
    (progn
      (setq plotter-name "DWG To PDF.pc3")
      (setq file-ext ".pdf"))
    (progn
      (setq plotter-name "DWF6 ePlot.pc3")
      (setq file-ext ".dwf"))
  )

  ;; ── 3. 저장 폴더 ──────────────────────────────────────────
  (setq dwf-folder
    (getstring T "\n저장 폴더 (Enter = 현재 도면 폴더): "))
  (if (or (null dwf-folder) (= dwf-folder ""))
    (setq dwf-folder
      (vl-filename-directory (vla-get-fullname doc))))
  (if (not (vl-file-directory-p dwf-folder))
    (progn (vl-mkdir dwf-folder)
           (princ (strcat "\n  폴더 생성: " dwf-folder))))

  ;; ── 4. 블록참조 수집 ──────────────────────────────────────
  (princ (strcat "\n" target-layer " 레이어 탐색 중..."))
  (setq borders '())
  (setq ss (ssget "X"
    (list '(0 . "INSERT") (cons 8 target-layer))))

  (if (null ss)
    (progn
      (princ "\n  자동 탐색 실패. 블록을 직접 선택하세요:")
      (setq ss (ssget '((0 . "INSERT"))))))

  (if (null ss)
    (progn (princ "\n선택 취소.") (exit)))

  ;; ── 5. BoundingBox 수집 ────────────────────────────────────
  (setq i 0)
  (repeat (sslength ss)
    (setq ent (ssname ss i))
    (setq obj (vlax-ename->vla-object ent))
    (if (not (vl-catch-all-error-p
               (vl-catch-all-apply
                 'vla-getboundingbox (list obj 'pt-min 'pt-max))))
      (progn
        (setq pt-min (vlax-safearray->list pt-min))
        (setq pt-max (vlax-safearray->list pt-max))
        (if (and (> (- (car pt-max) (car pt-min)) 500)
                 (> (- (cadr pt-max) (cadr pt-min)) 500))
          (setq borders (cons (list pt-min pt-max) borders)))))
    (setq i (1+ i)))

  (if (null borders)
    (progn (princ "\n유효한 블록 영역 없음.") (exit)))
  (princ (strcat "\n  " (itoa (length borders)) "개 감지."))

  ;; ── 6. 정렬 (위→아래, 좌→우) ──────────────────────────────
  (setq sorted-borders (dwfblk:sort-borders borders))

  ;; ── 7. 플롯 실행 ──────────────────────────────────────────
  (setq cnt 1 ok-cnt 0 fail-cnt 0)
  (foreach border sorted-borders
    (setq pt-min (car border))
    (setq pt-max (cadr border))
    (setq dwf-path
      (strcat dwf-folder "\\" "도면" (itoa cnt) file-ext))
    (princ (strcat "\n  [" (itoa cnt) "/"
      (itoa (length sorted-borders)) "] 도면" (itoa cnt) file-ext))

    (setq result
      (dwfblk:plot-to-file pt-min pt-max dwf-path plotter-name))
    (if result
      (setq ok-cnt (1+ ok-cnt))
      (setq fail-cnt (1+ fail-cnt)))
    (setq cnt (1+ cnt)))

  ;; ── 8. 결과 ────────────────────────────────────────────────
  (princ "\n\n========================================")
  (princ (strcat "\n  ✔ 성공: " (itoa ok-cnt) "개"))
  (if (> fail-cnt 0)
    (princ (strcat "\n  ✘ 실패: " (itoa fail-cnt) "개")))
  (princ (strcat "\n  위치: " dwf-folder))
  (princ "\n========================================\n")
  (princ))


;;; ── 레이어 선택 ──────────────────────────────────────────────
(defun dwfblk:select-layer (doc / layers layer-list layer-name
                                  mode sel-ent sel-obj
                                  input idx i)
  (setq layers (vla-get-layers doc))
  (setq layer-list '())
  (vlax-for layer-obj layers
    (setq layer-list
      (cons (vla-get-name layer-obj) layer-list)))
  (setq layer-list (reverse layer-list))

  (princ "\n\n레이어 선택:")
  (princ "\n  [1] 블록 클릭으로 자동 감지")
  (princ "\n  [2] 목록에서 번호 선택")
  (princ "\n  [3] 직접 입력")
  (initget "1 2 3")
  (setq mode (getkword "\n방법 [1/2/3] <1>: "))
  (if (null mode) (setq mode "1"))

  (cond
    ((= mode "1")
     (setq sel-ent (car (entsel "\n블록 클릭: ")))
     (if sel-ent
       (vla-get-layer (vlax-ename->vla-object sel-ent))
       nil))
    ((= mode "2")
     (princ "\n레이어 목록:")
     (setq i 1)
     (foreach lyr layer-list
       (princ (strcat "\n  [" (itoa i) "] " lyr))
       (setq i (1+ i)))
     (setq idx (getint "\n번호: "))
     (if (and idx (> idx 0) (<= idx (length layer-list)))
       (nth (1- idx) layer-list)
       nil))
    ((= mode "3")
     (setq input (getstring T "\n레이어명: "))
     (if (and input (/= input "")) input nil))
    (T nil)))


;;; ── 정렬: 평균 높이 기반 row-threshold ──────────────────────
(defun dwfblk:sort-borders (borders / heights avg-h thr)
  (setq heights '())
  (foreach b borders
    (setq heights
      (cons (abs (- (cadr (cadr b)) (cadr (car b)))) heights)))
  (setq avg-h (/ (apply '+ heights) (float (length heights))))
  (setq thr (* 0.4 avg-h))

  (vl-sort borders
    (function
      (lambda (a b / ay by ax bx)
        (setq ay (cadr (cadr a)) by (cadr (cadr b)))
        (setq ax (car (car a))   bx (car (car b)))
        (if (> (abs (- ay by)) thr)
          (> ay by) (< ax bx))))))


;;; ── 플롯: _.-PLOT 명령 사용 ─────────────────────────────────
;;; vla-PlotToFile / vla-get-Plot 대신 _.-PLOT 명령 직접 실행
;;; - 버전 호환성 확보 (vla-get-Plot 미지원 버전 대응)
;;; - 레이아웃 페이지 설정 변경 안 함
;;; - _ 접두사로 한/영 AutoCAD 모두 동작
;;;
;;; 참고: AutoCAD 버전에 따라 -PLOT 프롬프트 순서가
;;;       다소 다를 수 있음. 문제 시 프롬프트 응답 조정 필요.
(defun dwfblk:plot-to-file (pt-min pt-max filepath plotter
                             / old-ce old-bg old-fd old-err
                               x1s y1s x2s y2s plot-ok)
  ;; 에러 핸들러
  (setq old-err *error* plot-ok T)
  (defun *error* (msg)
    (setq plot-ok nil)
    (if (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\n    ✘ " msg)))
    (setvar "CMDECHO" old-ce)
    (setvar "BACKGROUNDPLOT" old-bg)
    (setvar "FILEDIA" old-fd)
    (setq *error* old-err))

  ;; 시스템 변수
  (setq old-ce (getvar "CMDECHO"))
  (setq old-bg (getvar "BACKGROUNDPLOT"))
  (setq old-fd (getvar "FILEDIA"))
  (setvar "CMDECHO" 0)
  (setvar "BACKGROUNDPLOT" 0)
  (setvar "FILEDIA" 0)

  ;; 진행중인 명령 취소
  (while (> (getvar "CMDACTIVE") 0) (command ""))

  ;; 좌표 문자열
  (setq x1s (rtos (car pt-min) 2 6)
        y1s (rtos (cadr pt-min) 2 6)
        x2s (rtos (car pt-max) 2 6)
        y2s (rtos (cadr pt-max) 2 6))

  ;; _.-PLOT 실행
  (command "_.-PLOT"
    "_Yes"                          ; 상세 설정
    ""                              ; 현재 레이아웃
    plotter                         ; 플로터
    ""                              ; 용지 (기본값)
    "_Millimeters"                  ; 단위
    "_Landscape"                    ; 방향
    "_No"                           ; 뒤집기
    "_Window"                       ; 영역
    (strcat x1s "," y1s)            ; 좌하단
    (strcat x2s "," y2s)            ; 우상단
    "_Fit"                          ; 스케일
    "0,0"                           ; 오프셋
    "_Yes"                          ; 플롯 스타일
    "."                             ; 스타일 테이블
    "_Yes"                          ; 선 가중치
    "_No"                           ; 선 가중치 스케일링
    filepath                        ; 출력 파일
    "_No"                           ; 설정 저장 안 함
    "_Yes"                          ; 진행
  )

  ;; 복원
  (setvar "CMDECHO" old-ce)
  (setvar "BACKGROUNDPLOT" old-bg)
  (setvar "FILEDIA" old-fd)
  (setq *error* old-err)

  ;; 결과
  (if plot-ok
    (if (findfile filepath)
      (progn (princ " ✔") T)
      (progn (princ " ✘ (파일 미생성)") nil))
    nil))


(princ "\n[export_dwf_by_block.lsp v3 로드]")
(princ "\n  명령: EXPORT-DWF  |  DWF/PDF 선택 가능")
(princ)
