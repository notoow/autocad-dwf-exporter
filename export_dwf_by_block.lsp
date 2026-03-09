;;; ============================================================
;;; export_dwf_by_block.lsp
;;;
;;; 기능: 모델 공간에서 "FORM" 레이어의 블록참조를 자동 감지,
;;;       각각의 영역을 도면1.dwf ~ 도면N.dwf 로 개별 플롯
;;;
;;; 사용법:
;;;   1. APPLOAD 로 로드
;;;   2. 명령창에 EXPORT-DWF 입력
;;;
;;; 전제조건:
;;;   - 테두리 블록이 "FORM" 레이어에 삽입되어 있음
;;;   - DWF6 ePlot.pc3 드라이버 설치됨
;;; ============================================================

(vl-load-com)

;;; ── 메인 명령 ────────────────────────────────────────────────
(defun c:EXPORT-DWF ( / doc acad
                       ss i ent obj
                       pt-min pt-max
                       borders sorted-borders
                       dwf-folder dwf-path
                       layout cnt)

  (setq acad (vlax-get-acad-object))
  (setq doc  (vla-get-activedocument acad))

  (princ "\n============================================")
  (princ "\n  DWF 일괄 내보내기 - FORM 블록 기준")
  (princ "\n============================================")

  ;; ── 1. DWF 저장 폴더 입력 ──────────────────────────────────
  (setq dwf-folder (getstring "\nDWF 저장 폴더 경로 입력 (Enter = 현재 도면 폴더): "))

  (if (or (null dwf-folder) (= dwf-folder ""))
    (setq dwf-folder
      (vl-filename-directory (vla-get-fullname doc)))
  )

  ;; 폴더 없으면 생성
  (if (not (vl-file-directory-p dwf-folder))
    (progn (vl-mkdir dwf-folder)
           (princ (strcat "\n폴더 생성됨: " dwf-folder)))
  )

  ;; ── 2. FORM 레이어의 블록참조 수집 ────────────────────────
  (princ "\nFORM 레이어 블록참조 탐색 중...")

  (setq borders '())

  ;; 방법 A: 레이어 "FORM" + INSERT (블록참조)
  (setq ss (ssget "X" '((0 . "INSERT") (8 . "FORM"))))

  ;; 못 찾으면 블록명으로 재탐색
  (if (null ss)
    (progn
      (princ "\n  FORM 레이어에서 못 찾음, 블록명으로 재탐색...")
      (setq ss (ssget "X" '((0 . "INSERT") (2 . "삼정환경 도면 폼*"))))
    )
  )

  ;; 그래도 없으면 수동 선택
  (if (null ss)
    (progn
      (princ "\n  자동 탐색 실패. 도면 테두리 블록들을 직접 선택하고 Enter:")
      (setq ss (ssget))
    )
  )

  (if (null ss)
    (progn (princ "\n선택 취소.") (exit))
  )

  ;; ── 3. 각 블록의 BoundingBox 수집 ─────────────────────────
  (setq i 0)
  (repeat (sslength ss)
    (setq ent (ssname ss i))
    (setq obj (vlax-ename->vla-object ent))

    ;; BoundingBox 취득
    (if (not (vl-catch-all-error-p
               (vl-catch-all-apply
                 'vla-getboundingbox
                 (list obj 'pt-min 'pt-max))))
      (progn
        (setq pt-min (vlax-safearray->list pt-min))
        (setq pt-max (vlax-safearray->list pt-max))

        ;; 최소 크기 필터 (너무 작은 건 제외)
        (if (and (> (- (car  pt-max) (car  pt-min)) 1000)
                 (> (- (cadr pt-max) (cadr pt-min)) 1000))
          (setq borders (cons (list pt-min pt-max) borders))
        )
      )
    )
    (setq i (1+ i))
  )

  (if (null borders)
    (progn (princ "\n유효한 블록 영역을 찾지 못했습니다.") (exit))
  )

  (princ (strcat "\n  " (itoa (length borders)) "개 블록 영역 감지됨."))

  ;; ── 4. 위→아래, 좌→우 정렬 ────────────────────────────────
  ;; 같은 행 판정: Y 차이가 블록 높이의 30% 이내면 같은 행
  (setq sorted-borders (sort-borders-by-position borders))

  ;; ── 5. 현재 레이아웃(모델 공간) 취득 ──────────────────────
  (setq layout (vla-get-activelayout doc))

  ;; ── 6. 순서대로 DWF 플롯 ───────────────────────────────────
  (setq cnt 1)
  (foreach border sorted-borders
    (setq pt-min (car  border))
    (setq pt-max (cadr border))
    (setq dwf-path (strcat dwf-folder "\\" "도면" (itoa cnt) ".dwf"))

    (princ (strcat "\n  플롯 [" (itoa cnt) "/" (itoa (length sorted-borders)) "] "
                   "→ 도면" (itoa cnt) ".dwf"))

    (plot-window-to-dwf doc layout pt-min pt-max dwf-path)

    (setq cnt (1+ cnt))
  )

  (princ (strcat "\n\n✔ 완료! " (itoa (1- cnt)) "개 DWF 파일 생성됨"))
  (princ (strcat "\n  저장 위치: " dwf-folder "\n"))
  (princ)
)


;;; ── 정렬 함수: 위→아래, 좌→우 ────────────────────────────────
(defun sort-borders-by-position (borders / row-threshold sorted)

  ;; 행 구분 임계값: 첫 번째 블록 높이의 40%
  (setq row-threshold
    (if borders
      (* 0.4 (- (cadr (cadr (car borders)))
                (cadr (car  (car borders)))))
      5000))

  ;; Y 내림차순 (위쪽 먼저), 같은 행은 X 오름차순
  (vl-sort borders
    (function
      (lambda (a b)
        (let* ((ay (cadr (cadr a)))
               (by (cadr (cadr b)))
               (ax (car  (car  a)))
               (bx (car  (car  b))))
          (if (> (abs (- ay by)) row-threshold)
            (> ay by)     ; Y 내림차순
            (< ax bx)     ; 같은 행: X 오름차순
          )
        )
      )
    )
  )
)


;;; ── 플롯 함수: Window 영역 → DWF 파일 ───────────────────────
(defun plot-window-to-dwf (doc layout pt-min pt-max dwf-path
                            / plot-obj
                              win-min win-max
                              lo-name)

  (setq plot-obj (vla-get-plot doc))
  (setq lo-name  (vla-get-name layout))

  ;; 윈도우 좌표 → SafeArray
  (setq win-min (vlax-make-safearray vlax-vbDouble '(0 . 1)))
  (vlax-safearray-put-element win-min 0 (car  pt-min))
  (vlax-safearray-put-element win-min 1 (cadr pt-min))

  (setq win-max (vlax-make-safearray vlax-vbDouble '(0 . 1)))
  (vlax-safearray-put-element win-max 0 (car  pt-max))
  (vlax-safearray-put-element win-max 1 (cadr pt-max))

  ;; 플롯 실행
  (vl-catch-all-apply
    'vla-PlotToFile
    (list
      plot-obj          ; Plot 객체
      lo-name           ; 레이아웃 이름
      dwf-path          ; 출력 파일 경로
      "DWF6 ePlot.pc3"  ; 플로터 드라이버
      "_NONE_"          ; 용지 (현재 페이지 설정 사용)
      acPlotWindow      ; 플롯 타입: Window
      :vlax-true        ; UseStandardScale
      acScaleToFit      ; 용지에 맞게
      ac0degrees        ; 회전 없음
      :vlax-true        ; 중앙 배치
      win-min           ; 좌하단
      win-max           ; 우상단
    )
  )
)


(princ "\n[export_dwf_by_block.lsp 로드 완료]")
(princ "\n  명령어: EXPORT-DWF")
(princ "\n  대상: FORM 레이어의 블록참조")
(princ)
