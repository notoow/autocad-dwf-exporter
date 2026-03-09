;;; ============================================================
;;; export_dwf_by_block.lsp
;;;
;;; 기능: 모델 공간에서 특정 레이어의 블록참조를 감지,
;;;       각각의 영역을 도면1.dwf ~ 도면N.dwf 로 개별 플롯
;;;
;;; 사용법:
;;;   1. APPLOAD 로 로드
;;;   2. 명령창에 EXPORT-DWF 입력
;;;   3. 레이어 선택 → 저장 폴더 지정 → 자동 내보내기
;;;
;;; 전제조건:
;;;   - 테두리 블록이 특정 레이어에 삽입되어 있음
;;;   - DWF6 ePlot.pc3 드라이버 설치됨
;;; ============================================================

(vl-load-com)

;;; ── 상수 정의 (AutoCAD COM 열거형 안전 보장) ──────────────
(if (not (boundp 'acWindow))      (setq acWindow 4))
(if (not (boundp 'acScaleToFit))  (setq acScaleToFit 0))
(if (not (boundp 'ac0degrees))    (setq ac0degrees 0))


;;; ── 메인 명령 ────────────────────────────────────────────────
(defun c:EXPORT-DWF ( / acad doc layout
                       target-layer ss i ent obj
                       pt-min pt-max
                       borders sorted-borders
                       dwf-folder dwf-path
                       cnt ok-cnt fail-cnt result)

  (setq acad (vlax-get-acad-object))
  (setq doc  (vla-get-activedocument acad))

  (princ "\n============================================")
  (princ "\n  DWF 일괄 내보내기 - 블록참조 기준")
  (princ "\n============================================")

  ;; ── 1. 레이어 선택 ────────────────────────────────────────
  (setq target-layer (dwfblk:select-layer doc))

  (if (null target-layer)
    (progn (princ "\n레이어 선택 취소.") (princ))
  )

  (if (null target-layer) (exit))

  (princ (strcat "\n  선택된 레이어: " target-layer))

  ;; ── 2. DWF 저장 폴더 입력 ──────────────────────────────────
  (setq dwf-folder (getstring T "\nDWF 저장 폴더 경로 (Enter = 현재 도면 폴더): "))

  (if (or (null dwf-folder) (= dwf-folder ""))
    (setq dwf-folder
      (vl-filename-directory (vla-get-fullname doc)))
  )

  ;; 폴더 없으면 생성
  (if (not (vl-file-directory-p dwf-folder))
    (progn (vl-mkdir dwf-folder)
           (princ (strcat "\n  폴더 생성됨: " dwf-folder)))
  )

  ;; ── 3. 선택된 레이어의 블록참조 수집 ──────────────────────
  (princ (strcat "\n" target-layer " 레이어 블록참조 탐색 중..."))

  (setq borders '())

  ;; 레이어 + INSERT (블록참조) 필터
  (setq ss (ssget "X"
    (list '(0 . "INSERT")
          (cons 8 target-layer))))

  ;; 못 찾으면 수동 선택
  (if (null ss)
    (progn
      (princ "\n  자동 탐색 실패. 도면 테두리 블록들을 직접 선택하고 Enter:")
      (setq ss (ssget '((0 . "INSERT"))))
    )
  )

  (if (null ss)
    (progn (princ "\n선택 취소.") (princ))
  )

  (if (null ss) (exit))

  ;; ── 4. 각 블록의 BoundingBox 수집 ─────────────────────────
  (setq i 0)
  (repeat (sslength ss)
    (setq ent (ssname ss i))
    (setq obj (vlax-ename->vla-object ent))

    ;; BoundingBox 취득 (에러 안전)
    (if (not (vl-catch-all-error-p
               (vl-catch-all-apply
                 'vla-getboundingbox
                 (list obj 'pt-min 'pt-max))))
      (progn
        (setq pt-min (vlax-safearray->list pt-min))
        (setq pt-max (vlax-safearray->list pt-max))

        ;; 최소 크기 필터 (너무 작은 건 제외)
        (if (and (> (- (car  pt-max) (car  pt-min)) 500)
                 (> (- (cadr pt-max) (cadr pt-min)) 500))
          (setq borders (cons (list pt-min pt-max) borders))
        )
      )
    )
    (setq i (1+ i))
  )

  (if (null borders)
    (progn (princ "\n유효한 블록 영역을 찾지 못했습니다.") (princ))
  )

  (if (null borders) (exit))

  (princ (strcat "\n  " (itoa (length borders)) "개 블록 영역 감지됨."))

  ;; ── 5. 위→아래, 좌→우 정렬 ────────────────────────────────
  (setq sorted-borders (dwfblk:sort-borders borders))

  ;; ── 6. 순서대로 DWF 플롯 ───────────────────────────────────
  (setq layout (vla-get-activelayout doc))
  (setq cnt 1)
  (setq ok-cnt 0)
  (setq fail-cnt 0)

  (foreach border sorted-borders
    (setq pt-min (car  border))
    (setq pt-max (cadr border))
    (setq dwf-path (strcat dwf-folder "\\" "도면" (itoa cnt) ".dwf"))

    (princ (strcat "\n  플롯 [" (itoa cnt) "/"
                   (itoa (length sorted-borders)) "] → 도면"
                   (itoa cnt) ".dwf"))

    (setq result
      (dwfblk:plot-region doc layout pt-min pt-max dwf-path "DWF6 ePlot.pc3"))

    (if result
      (setq ok-cnt (1+ ok-cnt))
      (setq fail-cnt (1+ fail-cnt))
    )

    (setq cnt (1+ cnt))
  )

  ;; ── 7. 결과 리포트 ────────────────────────────────────────
  (princ "\n\n========================================")
  (princ (strcat "\n  ✔ 성공: " (itoa ok-cnt) "개"))
  (if (> fail-cnt 0)
    (princ (strcat "\n  ✘ 실패: " (itoa fail-cnt) "개"))
  )
  (princ (strcat "\n  저장 위치: " dwf-folder))
  (princ "\n========================================\n")
  (princ)
)


;;; ── 레이어 선택: 도면의 레이어 목록에서 선택 ──────────────────
(defun dwfblk:select-layer (doc / layers layer-obj i
                                  layer-list layer-name
                                  mode sel-ent sel-obj
                                  input idx)

  ;; 레이어 목록 수집
  (setq layers (vla-get-layers doc))
  (setq layer-list '())
  (setq i 0)

  (vlax-for layer-obj layers
    (setq layer-name (vla-get-name layer-obj))
    ;; 동결/OFF 레이어도 포함 (블록이 있을 수 있으므로)
    (setq layer-list (cons layer-name layer-list))
  )

  (setq layer-list (reverse layer-list))

  ;; 선택 방식 안내
  (princ "\n\n레이어 선택 방법:")
  (princ "\n  [1] 테두리 블록을 클릭하여 레이어 자동 감지")
  (princ "\n  [2] 레이어 목록에서 번호로 선택")
  (princ "\n  [3] 레이어명 직접 입력")

  (initget "1 2 3")
  (setq mode (getkword "\n방법 선택 [1/2/3] <1>: "))
  (if (null mode) (setq mode "1"))

  (cond
    ;; ── 방법 1: 샘플 클릭 ──
    ((= mode "1")
     (princ "\n테두리 블록 하나를 클릭하세요...")
     (setq sel-ent (car (entsel "\n블록 선택: ")))
     (if sel-ent
       (progn
         (setq sel-obj (vlax-ename->vla-object sel-ent))
         (setq layer-name (vla-get-layer sel-obj))
         (princ (strcat "\n  감지된 레이어: " layer-name))
         layer-name
       )
       nil
     )
    )

    ;; ── 방법 2: 목록에서 선택 ──
    ((= mode "2")
     (princ "\n\n사용 가능한 레이어:")
     (setq i 1)
     (foreach lyr layer-list
       (princ (strcat "\n  [" (itoa i) "] " lyr))
       (setq i (1+ i))
     )
     (setq idx (getint "\n레이어 번호 입력: "))
     (if (and idx (> idx 0) (<= idx (length layer-list)))
       (nth (1- idx) layer-list)
       (progn (princ "\n  잘못된 번호입니다.") nil)
     )
    )

    ;; ── 방법 3: 직접 입력 ──
    ((= mode "3")
     (setq input (getstring T "\n레이어명 입력: "))
     (if (and input (/= input ""))
       input
       nil
     )
    )

    ;; 기본값
    (T nil)
  )
)


;;; ── 정렬 함수: 위→아래, 좌→우 ────────────────────────────────
(defun dwfblk:sort-borders (borders / row-threshold
                                      heights avg-height)

  ;; 행 구분 임계값: 전체 블록 평균 높이의 40%
  (setq heights '())
  (foreach b borders
    (setq heights
      (cons (abs (- (cadr (cadr b)) (cadr (car b))))
            heights))
  )
  (setq avg-height
    (/ (apply '+ heights) (float (length heights))))
  (setq row-threshold (* 0.4 avg-height))

  ;; Y 내림차순 (위쪽 먼저), 같은 행은 X 오름차순
  (vl-sort borders
    (function
      (lambda (a b / ay by ax bx)
        (setq ay (cadr (cadr a)))
        (setq by (cadr (cadr b)))
        (setq ax (car  (car  a)))
        (setq bx (car  (car  b)))
        (if (> (abs (- ay by)) row-threshold)
          (> ay by)      ; Y 내림차순
          (< ax bx)      ; 같은 행: X 오름차순
        )
      )
    )
  )
)


;;; ── 플롯 함수: Window 영역 → DWF 파일 (올바른 API 사용) ─────
(defun dwfblk:plot-region (doc layout pt-min pt-max
                            dwf-path plotter-name
                            / plot-obj win-min win-max
                              old-bgplot result)

  ;; 1. Background plot 끄기 (LISP에서 플롯 시 필수)
  (setq old-bgplot (getvar "BACKGROUNDPLOT"))
  (setvar "BACKGROUNDPLOT" 0)

  ;; 2. 레이아웃에 플롯 설정 적용
  (vl-catch-all-apply 'vla-put-ConfigName
    (list layout plotter-name))
  (vla-put-PlotType layout acWindow)         ; 4 = Window
  (vla-put-UseStandardScale layout :vlax-true)
  (vla-put-StandardScale layout acScaleToFit) ; 0 = Fit
  (vla-put-PlotRotation layout ac0degrees)    ; 0 = 회전없음
  (vla-put-CenterPlot layout :vlax-true)

  ;; 3. 윈도우 좌표 설정 (레이아웃 객체에 설정)
  (setq win-min (vlax-make-safearray vlax-vbDouble '(0 . 1)))
  (vlax-safearray-put-element win-min 0 (car  pt-min))
  (vlax-safearray-put-element win-min 1 (cadr pt-min))

  (setq win-max (vlax-make-safearray vlax-vbDouble '(0 . 1)))
  (vlax-safearray-put-element win-max 0 (car  pt-max))
  (vlax-safearray-put-element win-max 1 (cadr pt-max))

  (vla-SetWindowToPlot layout win-min win-max)

  ;; 4. 플롯 실행 (Plot 객체에서 파일명만 전달)
  (setq plot-obj (vla-get-Plot doc))
  (setq result
    (vl-catch-all-apply 'vla-PlotToFile
      (list plot-obj dwf-path)))

  ;; 5. 시스템 변수 복원
  (setvar "BACKGROUNDPLOT" old-bgplot)

  ;; 6. 결과 반환 (T=성공, nil=실패)
  (if (vl-catch-all-error-p result)
    (progn
      (princ (strcat "\n    ✘ 플롯 오류: "
               (vl-catch-all-error-message result)))
      nil)
    (progn
      (princ " ✔")
      T)
  )
)


(princ "\n[export_dwf_by_block.lsp 로드 완료]")
(princ "\n  명령어: EXPORT-DWF")
(princ "\n  대상: 선택한 레이어의 블록참조")
(princ)
