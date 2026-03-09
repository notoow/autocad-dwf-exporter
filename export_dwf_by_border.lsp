;;; ============================================================
;;; export_dwf_by_border.lsp
;;;
;;; 기능: UI 다이얼로그 또는 텍스트 모드를 통해
;;;       테두리(닫힌 폴리라인) 감지 → 개별 DWF 내보내기
;;;
;;; 감지 방식:
;;;   A) 샘플 선택 - 테두리 하나를 클릭하면 동일 속성 자동 탐색
;;;   B) 색상 입력 - ACI 번호 또는 RGB 값으로 직접 지정
;;;
;;; 사용법:
;;;   1. APPLOAD 로 로드
;;;   2. 명령창에 EXPORT-DWF-BORDERS 입력
;;;
;;; 전제조건:
;;;   - DWF6 ePlot.pc3 드라이버 설치
;;;   - 테두리가 LWPOLYLINE (닫힌 폴리라인)으로 그려져 있어야 함
;;; ============================================================

(vl-load-com)

;;; ── 상수 정의 ────────────────────────────────────────────────
(if (not (boundp 'acWindow))     (setq acWindow 4))
(if (not (boundp 'acScaleToFit)) (setq acScaleToFit 0))
(if (not (boundp 'ac0degrees))   (setq ac0degrees 0))


;;; ── 설정 데이터 구조 (연관 리스트로 관리) ─────────────────────
;;; 글로벌 변수 남발 대신, 단일 연관리스트에 모든 설정 보관
(setq *dwfbdr:config* nil)

(defun dwfbdr:config-init (doc)
  (setq *dwfbdr:config*
    (list
      (cons "mode"         "sample")     ; "sample" 또는 "manual"
      (cons "color-type"   "aci")        ; "aci" 또는 "rgb"
      (cons "aci"          1)            ; ACI 색상 번호
      (cons "rgb-r"        255)
      (cons "rgb-g"        0)
      (cons "rgb-b"        0)
      (cons "sample-color" nil)          ; 감지된 색상 (숫자=ACI, 리스트=RGB)
      (cons "sample-layer" nil)          ; 감지된 레이어명
      (cons "closed-only"  T)            ; 닫힌 폴리라인만
      (cons "layer-match"  nil)          ; 같은 레이어만
      (cons "min-size"     100)          ; 최소 크기
      (cons "folder"       (vl-filename-directory
                             (vla-get-fullname doc)))
      (cons "prefix"       "도면")
      (cons "plotter"      "DWF6 ePlot.pc3")
    )
  )
)

(defun dwfbdr:get (key)
  (cdr (assoc key *dwfbdr:config*)))

(defun dwfbdr:set (key val / pair)
  (setq pair (assoc key *dwfbdr:config*))
  (if pair
    (setq *dwfbdr:config*
      (subst (cons key val) pair *dwfbdr:config*))
    (setq *dwfbdr:config*
      (cons (cons key val) *dwfbdr:config*))
  )
)


;;; ────────────────────────────────────────────────────────────
;;; 메인 명령: EXPORT-DWF-BORDERS
;;; ────────────────────────────────────────────────────────────
(defun c:EXPORT-DWF-BORDERS ( / acad doc layout
                                dcl-file dcl-id dlg-result
                                borders sorted-borders
                                cnt ok-cnt fail-cnt
                                pt-min pt-max dwf-path result)

  (setq acad (vlax-get-acad-object))
  (setq doc  (vla-get-activedocument acad))

  ;; 설정 초기화
  (dwfbdr:config-init doc)

  (princ "\n========================================")
  (princ "\n  DWF 일괄 내보내기 - 테두리 감지 방식")
  (princ "\n========================================")

  ;; ── DCL 파일 찾기 ────────────────────────────────────────
  (setq dcl-file (findfile "export_dwf_border_ui.dcl"))

  ;; 못 찾으면 LSP와 같은 폴더에서 탐색
  (if (null dcl-file)
    (progn
      (setq dcl-file
        (strcat (vl-filename-directory
                  (findfile "export_dwf_by_border.lsp"))
                "\\export_dwf_border_ui.dcl"))
      (if (not (findfile dcl-file))
        (setq dcl-file nil))
    )
  )

  ;; DCL 없으면 텍스트 모드로 폴백
  (if (null dcl-file)
    (progn
      (princ "\n  DCL 파일 없음 → 텍스트 모드로 실행")
      (dwfbdr:textmode doc)
      (princ)
    )
  )

  (if (null dcl-file) (exit))

  ;; ── DCL 다이얼로그 실행 ──────────────────────────────────
  (setq dcl-id (load_dialog dcl-file))

  (if (< dcl-id 0)
    (progn
      (princ "\n[오류] DCL 파일 로드 실패 → 텍스트 모드로 전환")
      (dwfbdr:textmode doc)
      (princ)
    )
  )

  (if (< dcl-id 0) (exit))

  ;; 다이얼로그 초기화
  (if (not (new_dialog "dwf_border_dialog" dcl-id))
    (progn
      (princ "\n[오류] 다이얼로그 생성 실패.")
      (unload_dialog dcl-id)
      (princ)
    )
  )

  ;; 초기값 & 콜백 설정
  (dwfbdr:setup-dialog)

  ;; ── 다이얼로그 루프 ──────────────────────────────────────
  (setq dlg-result (start_dialog))

  ;; 샘플 선택 모드로 나온 경우 (코드 2)
  (while (= dlg-result 2)
    ;; 다이얼로그 밖에서 샘플 선택
    (dwfbdr:pick-sample)

    ;; 다이얼로그 다시 열기
    (if (not (new_dialog "dwf_border_dialog" dcl-id))
      (progn
        (princ "\n[오류] 다이얼로그 재생성 실패.")
        (unload_dialog dcl-id)
        (exit)
      )
    )

    ;; 설정 복원 & 샘플 정보 표시
    (dwfbdr:setup-dialog)
    (dwfbdr:show-sample-info)

    (setq dlg-result (start_dialog))
  )

  (unload_dialog dcl-id)

  ;; 취소 시 종료
  (if (/= dlg-result 1)
    (progn (princ "\n취소됨.") (princ))
  )

  (if (/= dlg-result 1) (exit))

  ;; ── 테두리 감지 & 플롯 실행 ──────────────────────────────
  (dwfbdr:execute-export doc)
  (princ)
)


;;; ────────────────────────────────────────────────────────────
;;; 다이얼로그 초기값 & 콜백 등록 (한 곳에서 관리)
;;; ────────────────────────────────────────────────────────────
(defun dwfbdr:setup-dialog ()
  ;; 초기값
  (set_tile "ed_folder"   (dwfbdr:get "folder"))
  (set_tile "ed_prefix"   (dwfbdr:get "prefix"))
  (set_tile "ed_plotter"  (dwfbdr:get "plotter"))
  (set_tile "ed_min_size" (itoa (dwfbdr:get "min-size")))
  (set_tile "ed_aci"      (itoa (dwfbdr:get "aci")))
  (set_tile "ed_r"        (itoa (dwfbdr:get "rgb-r")))
  (set_tile "ed_g"        (itoa (dwfbdr:get "rgb-g")))
  (set_tile "ed_b"        (itoa (dwfbdr:get "rgb-b")))

  ;; 콜백
  (action_tile "rb_sample"
    "(dwfbdr:set \"mode\" \"sample\")")
  (action_tile "rb_manual"
    "(dwfbdr:set \"mode\" \"manual\")")
  (action_tile "rb_aci"
    "(dwfbdr:set \"color-type\" \"aci\")")
  (action_tile "rb_rgb"
    "(dwfbdr:set \"color-type\" \"rgb\")")

  (action_tile "btn_pick"    "(done_dialog 2)")
  (action_tile "btn_browse"  "(dwfbdr:browse-folder)")
  (action_tile "btn_preview" "(dwfbdr:preview)")

  (action_tile "ed_aci"      "(dwfbdr:set \"aci\"      (atoi $value))")
  (action_tile "ed_r"        "(dwfbdr:set \"rgb-r\"    (atoi $value))")
  (action_tile "ed_g"        "(dwfbdr:set \"rgb-g\"    (atoi $value))")
  (action_tile "ed_b"        "(dwfbdr:set \"rgb-b\"    (atoi $value))")
  (action_tile "ed_folder"   "(dwfbdr:set \"folder\"   $value)")
  (action_tile "ed_prefix"   "(dwfbdr:set \"prefix\"   $value)")
  (action_tile "ed_plotter"  "(dwfbdr:set \"plotter\"  $value)")
  (action_tile "ed_min_size" "(dwfbdr:set \"min-size\"  (atoi $value))")
  (action_tile "chk_closed"
    "(dwfbdr:set \"closed-only\" (= $value \"1\"))")
  (action_tile "chk_layer_match"
    "(dwfbdr:set \"layer-match\" (= $value \"1\"))")

  (action_tile "accept"
    "(dwfbdr:save-dialog-values) (done_dialog 1)")
  (action_tile "cancel" "(done_dialog 0)")
)


;;; ── 다이얼로그 값 저장 ──────────────────────────────────────
(defun dwfbdr:save-dialog-values ()
  (dwfbdr:set "folder"   (get_tile "ed_folder"))
  (dwfbdr:set "prefix"   (get_tile "ed_prefix"))
  (dwfbdr:set "plotter"  (get_tile "ed_plotter"))
  (dwfbdr:set "min-size" (atoi (get_tile "ed_min_size")))
  (dwfbdr:set "aci"      (atoi (get_tile "ed_aci")))
  (dwfbdr:set "rgb-r"    (atoi (get_tile "ed_r")))
  (dwfbdr:set "rgb-g"    (atoi (get_tile "ed_g")))
  (dwfbdr:set "rgb-b"    (atoi (get_tile "ed_b")))
)


;;; ── 샘플 선택 정보 표시 ─────────────────────────────────────
(defun dwfbdr:show-sample-info ( / sc)
  (setq sc (dwfbdr:get "sample-color"))
  (if sc
    (progn
      (set_tile "txt_sample_info" "✔ 샘플 선택됨")
      (set_tile "txt_detected_color"
        (if (listp sc)
          (strcat "RGB("
            (itoa (car sc)) ","
            (itoa (cadr sc)) ","
            (itoa (caddr sc)) ")")
          (strcat "ACI " (itoa sc))
        )
      )
      (set_tile "txt_detected_layer"
        (if (dwfbdr:get "sample-layer")
          (dwfbdr:get "sample-layer") "-"))
    )
  )
)


;;; ── 폴더 찾아보기 ────────────────────────────────────────────
(defun dwfbdr:browse-folder ( / shell folder-obj folder-path)
  (setq shell (vlax-create-object "Shell.Application"))
  (if shell
    (progn
      (setq folder-obj
        (vlax-invoke-method shell 'BrowseForFolder
          0 "DWF 저장 폴더를 선택하세요" 0 ""))
      (if folder-obj
        (progn
          (setq folder-path
            (vlax-get-property
              (vlax-get-property folder-obj 'Self) 'Path))
          ;; 마지막 \ 제거
          (if (= (substr folder-path (strlen folder-path)) "\\")
            (setq folder-path
              (substr folder-path 1 (1- (strlen folder-path)))))
          (dwfbdr:set "folder" folder-path)
          (set_tile "ed_folder" folder-path)
        )
      )
      (vlax-release-object shell)
    )
  )
)


;;; ── 미리보기 (감지 결과 카운트) ──────────────────────────────
(defun dwfbdr:preview ( / doc borders n)
  (setq doc (vla-get-activedocument (vlax-get-acad-object)))
  (setq borders (dwfbdr:detect-borders doc))
  (setq n (if borders (length borders) 0))
  (set_tile "txt_count"
    (strcat "감지된 테두리: " (itoa n) "개"))
)


;;; ────────────────────────────────────────────────────────────
;;; 샘플 선택: 사용자가 클릭한 객체에서 속성 추출
;;; ────────────────────────────────────────────────────────────
(defun dwfbdr:pick-sample ( / ent obj layer-name
                              true-color color-val
                              r g b dxf-color)

  (princ "\n테두리 사각형 하나를 클릭하세요...")
  (setq ent (car (entsel "\n테두리 선택: ")))

  (if (null ent)
    (progn (princ "\n  선택 취소됨.") nil)
    (progn
      (setq obj (vlax-ename->vla-object ent))

      ;; 레이어명 추출
      (setq layer-name (vla-get-layer obj))
      (dwfbdr:set "sample-layer" layer-name)

      ;; 색상 추출 시도
      ;; 1) TrueColor (RGB)
      (setq true-color
        (vl-catch-all-apply 'vla-get-truecolor (list obj)))

      (if (and (not (vl-catch-all-error-p true-color))
               true-color)
        (progn
          ;; ColorMethod 체크: ByACI가 아니면 RGB
          (if (not (vl-catch-all-error-p
                     (vl-catch-all-apply 'vla-get-colormethod
                       (list true-color))))
            (progn
              (setq r (vla-get-red   true-color))
              (setq g (vla-get-green true-color))
              (setq b (vla-get-blue  true-color))

              ;; 순수 ACI 색상 확인 (Red=ACI 1 등)
              (setq color-val
                (vl-catch-all-apply 'vla-get-color (list obj)))

              (if (and (not (vl-catch-all-error-p color-val))
                       (numberp color-val)
                       (/= color-val 256))
                ;; ACI 색상
                (progn
                  (dwfbdr:set "sample-color" color-val)
                  (dwfbdr:set "color-type" "aci")
                  (dwfbdr:set "aci" color-val)
                  (princ (strcat "\n  색상: ACI " (itoa color-val)))
                )
                ;; RGB 색상
                (progn
                  (dwfbdr:set "sample-color" (list r g b))
                  (dwfbdr:set "color-type" "rgb")
                  (dwfbdr:set "rgb-r" r)
                  (dwfbdr:set "rgb-g" g)
                  (dwfbdr:set "rgb-b" b)
                  (princ (strcat "\n  색상: RGB("
                    (itoa r) "," (itoa g) "," (itoa b) ")"))
                )
              )
            )
          )
        )
        ;; TrueColor 실패 → DXF에서 직접 읽기
        (progn
          (setq dxf-color (cdr (assoc 62 (entget ent))))
          (if dxf-color
            (progn
              (dwfbdr:set "sample-color" dxf-color)
              (dwfbdr:set "color-type" "aci")
              (dwfbdr:set "aci" dxf-color)
              (princ (strcat "\n  색상 (DXF): ACI " (itoa dxf-color)))
            )
            (progn
              (dwfbdr:set "sample-color" 256) ; ByLayer
              (princ "\n  색상: ByLayer")
            )
          )
        )
      )

      (princ (strcat "\n  레이어: " layer-name))
      T
    )
  )
)


;;; ────────────────────────────────────────────────────────────
;;; 테두리 감지: 설정에 따라 매칭하는 폴리라인 수집
;;; ────────────────────────────────────────────────────────────
(defun dwfbdr:detect-borders (doc / ss filter-list
                                    i ent obj
                                    pt-min pt-max
                                    borders match-p
                                    true-color r g b
                                    sc min-sz)

  ;; 기본 필터: LWPOLYLINE
  (setq filter-list '((0 . "LWPOLYLINE")))

  ;; 닫힌 폴리라인만
  (if (dwfbdr:get "closed-only")
    (setq filter-list (append filter-list '((70 . 1))))
  )

  ;; ACI 색상 필터 (가능할 때만)
  (cond
    ((and (= (dwfbdr:get "mode") "sample")
          (numberp (dwfbdr:get "sample-color"))
          (/= (dwfbdr:get "sample-color") 256))
     (setq filter-list
       (append filter-list
         (list (cons 62 (dwfbdr:get "sample-color")))))
    )
    ((and (= (dwfbdr:get "mode") "manual")
          (= (dwfbdr:get "color-type") "aci"))
     (setq filter-list
       (append filter-list
         (list (cons 62 (dwfbdr:get "aci")))))
    )
  )

  ;; 레이어 매칭
  (if (and (dwfbdr:get "layer-match")
           (dwfbdr:get "sample-layer"))
    (setq filter-list
      (append filter-list
        (list (cons 8 (dwfbdr:get "sample-layer")))))
  )

  ;; 선택 세트 생성
  (setq ss (ssget "X" filter-list))

  (if (null ss)
    (progn
      (princ "\n  필터 조건에 맞는 객체 없음.")
      nil
    )
    (progn
      ;; 결과 수집
      (setq borders '())
      (setq min-sz (dwfbdr:get "min-size"))
      (setq sc (dwfbdr:get "sample-color"))
      (setq i 0)

      (repeat (sslength ss)
        (setq ent (ssname ss i))
        (setq obj (vlax-ename->vla-object ent))
        (setq match-p T)

        ;; RGB 색상 후처리 (ssget 필터로 못 잡는 경우)
        (if (and match-p
                 (or
                   (and (= (dwfbdr:get "mode") "sample")
                        (listp sc))
                   (and (= (dwfbdr:get "mode") "manual")
                        (= (dwfbdr:get "color-type") "rgb"))
                 ))
          (progn
            (setq true-color
              (vl-catch-all-apply 'vla-get-truecolor (list obj)))
            (if (not (vl-catch-all-error-p true-color))
              (progn
                (setq r (vla-get-red   true-color))
                (setq g (vla-get-green true-color))
                (setq b (vla-get-blue  true-color))
                (if (= (dwfbdr:get "mode") "sample")
                  ;; 샘플 RGB 비교
                  (if (not (and (= r (car   sc))
                                (= g (cadr  sc))
                                (= b (caddr sc))))
                    (setq match-p nil)
                  )
                  ;; 수동 RGB 비교
                  (if (not (and (= r (dwfbdr:get "rgb-r"))
                                (= g (dwfbdr:get "rgb-g"))
                                (= b (dwfbdr:get "rgb-b"))))
                    (setq match-p nil)
                  )
                )
              )
              (setq match-p nil)
            )
          )
        )

        ;; BoundingBox + 최소 크기 필터
        (if match-p
          (if (not (vl-catch-all-error-p
                     (vl-catch-all-apply
                       'vla-getboundingbox
                       (list obj 'pt-min 'pt-max))))
            (progn
              (setq pt-min (vlax-safearray->list pt-min))
              (setq pt-max (vlax-safearray->list pt-max))
              (if (and (> (- (car  pt-max) (car  pt-min)) min-sz)
                       (> (- (cadr pt-max) (cadr pt-min)) min-sz))
                (setq borders (cons (list pt-min pt-max) borders))
              )
            )
          )
        )

        (setq i (1+ i))
      )

      borders
    )
  )
)


;;; ── 정렬: 위→아래 (Y 내림), 같은 행은 좌→우 (X 오름) ─────
(defun dwfbdr:sort-borders (borders / heights avg-height
                                      row-threshold)
  ;; 전체 블록 평균 높이의 40%를 행 구분 임계값으로 사용
  (setq heights '())
  (foreach b borders
    (setq heights
      (cons (abs (- (cadr (cadr b)) (cadr (car b))))
            heights))
  )
  (setq avg-height
    (/ (apply '+ heights) (float (length heights))))
  (setq row-threshold (* 0.4 avg-height))

  (vl-sort borders
    (function
      (lambda (a b / ay by ax bx)
        (setq ay (cadr (cadr a)))
        (setq by (cadr (cadr b)))
        (setq ax (car  (car  a)))
        (setq bx (car  (car  b)))
        (if (> (abs (- ay by)) row-threshold)
          (> ay by)
          (< ax bx)
        )
      )
    )
  )
)


;;; ── 플롯: Window 영역 → DWF 파일 (올바른 API) ─────────────
(defun dwfbdr:plot-region (doc layout pt-min pt-max
                            dwf-path plotter-name
                            / plot-obj win-min win-max
                              old-bgplot result)

  ;; 1. Background plot 끄기
  (setq old-bgplot (getvar "BACKGROUNDPLOT"))
  (setvar "BACKGROUNDPLOT" 0)

  ;; 2. 레이아웃에 플롯 설정 적용
  (vl-catch-all-apply 'vla-put-ConfigName
    (list layout plotter-name))
  (vla-put-PlotType layout acWindow)
  (vla-put-UseStandardScale layout :vlax-true)
  (vla-put-StandardScale layout acScaleToFit)
  (vla-put-PlotRotation layout ac0degrees)
  (vla-put-CenterPlot layout :vlax-true)

  ;; 3. 윈도우 좌표 설정 (레이아웃에 설정)
  (setq win-min (vlax-make-safearray vlax-vbDouble '(0 . 1)))
  (vlax-safearray-put-element win-min 0 (car  pt-min))
  (vlax-safearray-put-element win-min 1 (cadr pt-min))

  (setq win-max (vlax-make-safearray vlax-vbDouble '(0 . 1)))
  (vlax-safearray-put-element win-max 0 (car  pt-max))
  (vlax-safearray-put-element win-max 1 (cadr pt-max))

  (vla-SetWindowToPlot layout win-min win-max)

  ;; 4. 플롯 실행 (Plot 객체 + 파일명만 전달)
  (setq plot-obj (vla-get-Plot doc))
  (setq result
    (vl-catch-all-apply 'vla-PlotToFile
      (list plot-obj dwf-path)))

  ;; 5. 시스템 변수 복원
  (setvar "BACKGROUNDPLOT" old-bgplot)

  ;; 6. 결과 반환
  (if (vl-catch-all-error-p result)
    (progn
      (princ (strcat "\n    ✘ 오류: "
               (vl-catch-all-error-message result)))
      nil)
    (progn
      (princ " ✔")
      T)
  )
)


;;; ── 내보내기 실행 (공통 로직) ────────────────────────────────
(defun dwfbdr:execute-export (doc / borders sorted-borders
                                    layout cnt ok-cnt fail-cnt
                                    pt-min pt-max dwf-path
                                    folder prefix plotter result)

  (setq borders (dwfbdr:detect-borders doc))

  (if (or (null borders) (= (length borders) 0))
    (progn
      (princ "\n[오류] 테두리를 찾을 수 없습니다.")
      (princ "\n  설정을 확인하고 다시 시도해 주세요.")
    )
    (progn
      (princ (strcat "\n  " (itoa (length borders)) "개 테두리 감지됨."))

      ;; 정렬
      (setq sorted-borders (dwfbdr:sort-borders borders))

      ;; 폴더 확인/생성
      (setq folder (dwfbdr:get "folder"))
      (if (not (vl-file-directory-p folder))
        (progn
          (vl-mkdir folder)
          (princ (strcat "\n  폴더 생성: " folder)))
      )

      ;; 플롯 설정
      (setq layout  (vla-get-activelayout doc))
      (setq prefix  (dwfbdr:get "prefix"))
      (setq plotter (dwfbdr:get "plotter"))
      (setq cnt 1)
      (setq ok-cnt 0)
      (setq fail-cnt 0)

      (foreach border sorted-borders
        (setq pt-min (car  border))
        (setq pt-max (cadr border))
        (setq dwf-path
          (strcat folder "\\" prefix (itoa cnt) ".dwf"))

        (princ (strcat "\n  플롯 ["
          (itoa cnt) "/" (itoa (length sorted-borders))
          "] → " prefix (itoa cnt) ".dwf"))

        (setq result
          (dwfbdr:plot-region doc layout pt-min pt-max
                              dwf-path plotter))

        (if result
          (setq ok-cnt (1+ ok-cnt))
          (setq fail-cnt (1+ fail-cnt))
        )

        (setq cnt (1+ cnt))
      )

      ;; 결과 리포트
      (princ "\n\n========================================")
      (princ (strcat "\n  ✔ 성공: " (itoa ok-cnt) "개"))
      (if (> fail-cnt 0)
        (princ (strcat "\n  ✘ 실패: " (itoa fail-cnt) "개")))
      (princ (strcat "\n  저장 위치: " folder))
      (princ "\n========================================\n")
    )
  )
)


;;; ────────────────────────────────────────────────────────────
;;; 텍스트 모드 (DCL 없을 때 폴백)
;;; ────────────────────────────────────────────────────────────
(defun dwfbdr:textmode (doc / mode aci-val folder)

  (princ "\n\n[텍스트 모드] DCL 파일 없이 실행합니다.")
  (princ "\n========================================\n")

  ;; 모드 선택
  (initget "Sample Manual")
  (setq mode
    (getkword "\n감지 방식 [Sample 선택/Manual 색상입력] <Sample>: "))
  (if (null mode) (setq mode "Sample"))

  (cond
    ((= mode "Sample")
     (dwfbdr:pick-sample)
    )
    ((= mode "Manual")
     (setq aci-val (getint "\nACI 색상 번호 (1=빨강, 2=노랑 ...): "))
     (if aci-val
       (progn
         (dwfbdr:set "aci" aci-val)
         (dwfbdr:set "mode" "manual")
         (dwfbdr:set "color-type" "aci")
       )
     )
    )
  )

  ;; 폴더 입력
  (setq folder
    (getstring T
      (strcat "\nDWF 저장 폴더 [" (dwfbdr:get "folder") "]: ")))
  (if (and folder (/= folder ""))
    (dwfbdr:set "folder" folder)
  )

  ;; 실행
  (dwfbdr:execute-export doc)
)


;;; ── 로드 메시지 ──────────────────────────────────────────────
(princ "\n[export_dwf_by_border.lsp 로드 완료]")
(princ "\n  명령어: EXPORT-DWF-BORDERS")
(princ "\n  기능: 테두리 감지 & DWF 일괄 내보내기 (UI/텍스트 모드)")
(princ)
