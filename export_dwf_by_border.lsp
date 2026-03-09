;;; ============================================================
;;; export_dwf_by_border.lsp
;;;
;;; 기능: UI 다이얼로그를 통해 테두리 감지 방식을 선택하고
;;;       각 테두리 영역을 개별 DWF 파일로 일괄 내보내기
;;;
;;; 감지 방식:
;;;   A) 샘플 선택 - 테두리 하나를 클릭하면 동일 속성을 자동 탐색
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

;;; ────────────────────────────────────────────────────────────
;;; 글로벌 변수 (다이얼로그 ↔ 콜백 간 데이터 전달)
;;; ────────────────────────────────────────────────────────────
(setq *dwf:mode*         "sample")   ; "sample" 또는 "manual"
(setq *dwf:color-type*   "aci")      ; "aci" 또는 "rgb"
(setq *dwf:aci*          1)          ; ACI 색상 번호
(setq *dwf:rgb-r*        255)        ; RGB R
(setq *dwf:rgb-g*        0)          ; RGB G
(setq *dwf:rgb-b*        0)          ; RGB B
(setq *dwf:sample-color* nil)        ; 샘플에서 읽은 색상 정보
(setq *dwf:sample-layer* nil)        ; 샘플에서 읽은 레이어명
(setq *dwf:sample-ent*   nil)        ; 샘플 엔티티
(setq *dwf:closed-only*  T)          ; 닫힌 폴리라인만
(setq *dwf:layer-match*  nil)        ; 같은 레이어만
(setq *dwf:min-size*     100)        ; 최소 크기
(setq *dwf:folder*       "")         ; 저장 폴더
(setq *dwf:prefix*       "도면")     ; 파일명 접두사
(setq *dwf:plotter*      "DWF6 ePlot.pc3")  ; 플로터 이름
(setq *dwf:borders*      nil)        ; 감지된 테두리 목록
(setq *dwf:dcl-id*       nil)        ; DCL 파일 핸들


;;; ────────────────────────────────────────────────────────────
;;; 메인 명령: EXPORT-DWF-BORDERS
;;; ────────────────────────────────────────────────────────────
(defun c:EXPORT-DWF-BORDERS ( / dcl-file dcl-id dlg-result
                                doc acad layout
                                sorted-borders cnt
                                pt-min pt-max dwf-path)

  (setq acad (vlax-get-acad-object))
  (setq doc  (vla-get-activedocument acad))

  ;; 기본 폴더: 현재 도면 폴더
  (if (or (null *dwf:folder*) (= *dwf:folder* ""))
    (setq *dwf:folder*
      (vl-filename-directory (vla-get-fullname doc)))
  )

  ;; ── DCL 파일 로드 ────────────────────────────────────────
  (setq dcl-file (findfile "export_dwf_border_ui.dcl"))

  (if (null dcl-file)
    (progn
      ;; DCL 못 찾으면 lsp 파일과 같은 폴더에서 탐색
      (setq dcl-file
        (strcat (vl-filename-directory
                  (findfile "export_dwf_by_border.lsp"))
                "\\export_dwf_border_ui.dcl"))
    )
  )

  (if (not (findfile dcl-file))
    (progn
      (princ "\n[오류] export_dwf_border_ui.dcl 파일을 찾을 수 없습니다.")
      (princ "\n  LSP 파일과 같은 폴더에 DCL 파일을 배치해 주세요.")
      ;; DCL 없으면 텍스트 모드로 폴백
      (export-dwf-borders-textmode doc)
      (exit)
    )
  )

  (setq dcl-id (load_dialog dcl-file))
  (setq *dwf:dcl-id* dcl-id)

  (if (< dcl-id 0)
    (progn
      (princ "\n[오류] DCL 파일 로드 실패.")
      (exit)
    )
  )

  ;; 다이얼로그 초기화
  (if (not (new_dialog "dwf_border_dialog" dcl-id))
    (progn
      (princ "\n[오류] 다이얼로그 생성 실패.")
      (unload_dialog dcl-id)
      (exit)
    )
  )

  ;; ── 초기값 설정 ──────────────────────────────────────────
  (set_tile "ed_folder"  *dwf:folder*)
  (set_tile "ed_prefix"  *dwf:prefix*)
  (set_tile "ed_plotter" *dwf:plotter*)
  (set_tile "ed_min_size" (itoa *dwf:min-size*))
  (set_tile "ed_aci"     (itoa *dwf:aci*))
  (set_tile "ed_r"       (itoa *dwf:rgb-r*))
  (set_tile "ed_g"       (itoa *dwf:rgb-g*))
  (set_tile "ed_b"       (itoa *dwf:rgb-b*))

  ;; ── 콜백 등록 ────────────────────────────────────────────
  ;; 모드 전환
  (action_tile "rb_sample"
    "(setq *dwf:mode* \"sample\") (dwf-ui-toggle-mode)")
  (action_tile "rb_manual"
    "(setq *dwf:mode* \"manual\") (dwf-ui-toggle-mode)")

  ;; 색상 타입 전환
  (action_tile "rb_aci"
    "(setq *dwf:color-type* \"aci\")")
  (action_tile "rb_rgb"
    "(setq *dwf:color-type* \"rgb\")")

  ;; 샘플 선택 버튼
  (action_tile "btn_pick"
    "(done_dialog 2)")  ; 코드 2 = 샘플 선택 모드로 나가기

  ;; 폴더 찾아보기
  (action_tile "btn_browse"
    "(dwf-ui-browse-folder)")

  ;; 미리보기 (감지 실행)
  (action_tile "btn_preview"
    "(dwf-ui-preview)")

  ;; 값 변경 콜백
  (action_tile "ed_aci"      "(setq *dwf:aci*      (atoi $value))")
  (action_tile "ed_r"        "(setq *dwf:rgb-r*    (atoi $value))")
  (action_tile "ed_g"        "(setq *dwf:rgb-g*    (atoi $value))")
  (action_tile "ed_b"        "(setq *dwf:rgb-b*    (atoi $value))")
  (action_tile "ed_folder"   "(setq *dwf:folder*   $value)")
  (action_tile "ed_prefix"   "(setq *dwf:prefix*   $value)")
  (action_tile "ed_plotter"  "(setq *dwf:plotter*  $value)")
  (action_tile "ed_min_size" "(setq *dwf:min-size* (atoi $value))")
  (action_tile "chk_closed"  "(setq *dwf:closed-only* (= $value \"1\"))")
  (action_tile "chk_layer_match" "(setq *dwf:layer-match* (= $value \"1\"))")

  ;; 확인/취소
  (action_tile "accept" "(dwf-ui-save-values) (done_dialog 1)")
  (action_tile "cancel" "(done_dialog 0)")

  ;; 초기 모드 적용
  (dwf-ui-toggle-mode)

  ;; ── 다이얼로그 루프 ──────────────────────────────────────
  (setq dlg-result (start_dialog))

  ;; 샘플 선택 모드로 나왔을 때 (코드 2)
  (while (= dlg-result 2)
    ;; 다이얼로그 바깥에서 샘플 선택 수행
    (dwf-pick-sample doc)

    ;; 다이얼로그 재오픈
    (if (not (new_dialog "dwf_border_dialog" dcl-id))
      (progn
        (princ "\n[오류] 다이얼로그 재생성 실패.")
        (unload_dialog dcl-id)
        (exit)
      )
    )

    ;; 값 복원
    (set_tile "ed_folder"   *dwf:folder*)
    (set_tile "ed_prefix"   *dwf:prefix*)
    (set_tile "ed_plotter"  *dwf:plotter*)
    (set_tile "ed_min_size" (itoa *dwf:min-size*))
    (set_tile "ed_aci"      (itoa *dwf:aci*))
    (set_tile "ed_r"        (itoa *dwf:rgb-r*))
    (set_tile "ed_g"        (itoa *dwf:rgb-g*))
    (set_tile "ed_b"        (itoa *dwf:rgb-b*))

    ;; 샘플 정보 표시
    (if *dwf:sample-color*
      (progn
        (set_tile "txt_sample_info"
          (strcat "✔ 샘플 선택됨"))
        (set_tile "txt_detected_color"
          (if (listp *dwf:sample-color*)
            (strcat "RGB("
              (itoa (car   *dwf:sample-color*)) ","
              (itoa (cadr  *dwf:sample-color*)) ","
              (itoa (caddr *dwf:sample-color*)) ")")
            (strcat "ACI " (itoa *dwf:sample-color*))
          )
        )
        (set_tile "txt_detected_layer"
          (if *dwf:sample-layer* *dwf:sample-layer* "-"))
      )
    )

    ;; 콜백 재등록
    (action_tile "rb_sample"
      "(setq *dwf:mode* \"sample\") (dwf-ui-toggle-mode)")
    (action_tile "rb_manual"
      "(setq *dwf:mode* \"manual\") (dwf-ui-toggle-mode)")
    (action_tile "rb_aci"
      "(setq *dwf:color-type* \"aci\")")
    (action_tile "rb_rgb"
      "(setq *dwf:color-type* \"rgb\")")
    (action_tile "btn_pick"    "(done_dialog 2)")
    (action_tile "btn_browse"  "(dwf-ui-browse-folder)")
    (action_tile "btn_preview" "(dwf-ui-preview)")
    (action_tile "ed_aci"      "(setq *dwf:aci*      (atoi $value))")
    (action_tile "ed_r"        "(setq *dwf:rgb-r*    (atoi $value))")
    (action_tile "ed_g"        "(setq *dwf:rgb-g*    (atoi $value))")
    (action_tile "ed_b"        "(setq *dwf:rgb-b*    (atoi $value))")
    (action_tile "ed_folder"   "(setq *dwf:folder*   $value)")
    (action_tile "ed_prefix"   "(setq *dwf:prefix*   $value)")
    (action_tile "ed_plotter"  "(setq *dwf:plotter*  $value)")
    (action_tile "ed_min_size" "(setq *dwf:min-size* (atoi $value))")
    (action_tile "chk_closed"  "(setq *dwf:closed-only* (= $value \"1\"))")
    (action_tile "chk_layer_match" "(setq *dwf:layer-match* (= $value \"1\"))")
    (action_tile "accept" "(dwf-ui-save-values) (done_dialog 1)")
    (action_tile "cancel" "(done_dialog 0)")

    (set_tile "rb_sample" "1")
    (dwf-ui-toggle-mode)

    (setq dlg-result (start_dialog))
  )

  (unload_dialog dcl-id)

  ;; ── 취소 시 종료 ──────────────────────────────────────────
  (if (/= dlg-result 1)
    (progn (princ "\n취소됨.") (exit))
  )

  ;; ── 테두리 감지 실행 ──────────────────────────────────────
  (princ "\n\n========================================")
  (princ "\n  DWF 일괄 내보내기 실행")
  (princ "\n========================================")

  (setq *dwf:borders* (dwf-detect-borders doc))

  (if (or (null *dwf:borders*) (= (length *dwf:borders*) 0))
    (progn
      (princ "\n[오류] 테두리를 찾을 수 없습니다.")
      (princ "\n  설정을 확인하고 다시 시도해 주세요.")
      (exit)
    )
  )

  (princ (strcat "\n  " (itoa (length *dwf:borders*)) "개 테두리 감지됨."))

  ;; ── 정렬 (위→아래, 좌→우) ──────────────────────────────
  (setq sorted-borders (dwf-sort-borders *dwf:borders*))

  ;; ── 폴더 확인/생성 ────────────────────────────────────────
  (if (not (vl-file-directory-p *dwf:folder*))
    (progn
      (vl-mkdir *dwf:folder*)
      (princ (strcat "\n  폴더 생성: " *dwf:folder*))
    )
  )

  ;; ── 레이아웃 취득 ──────────────────────────────────────────
  (setq layout (vla-get-activelayout doc))

  ;; ── 순서대로 DWF 플롯 ──────────────────────────────────────
  (setq cnt 1)
  (foreach border sorted-borders
    (setq pt-min (car  border))
    (setq pt-max (cadr border))
    (setq dwf-path
      (strcat *dwf:folder* "\\"
              *dwf:prefix* (itoa cnt) ".dwf"))

    (princ (strcat "\n  플롯 ["
      (itoa cnt) "/" (itoa (length sorted-borders))
      "] → " *dwf:prefix* (itoa cnt) ".dwf"))

    (dwf-plot-window doc layout pt-min pt-max dwf-path)

    (setq cnt (1+ cnt))
  )

  (princ (strcat "\n\n✔ 완료! " (itoa (1- cnt)) "개 DWF 파일 생성됨"))
  (princ (strcat "\n  저장 위치: " *dwf:folder* "\n"))
  (princ)
)


;;; ────────────────────────────────────────────────────────────
;;; UI 헬퍼: 모드 전환 시 UI 상태 토글
;;; ────────────────────────────────────────────────────────────
(defun dwf-ui-toggle-mode ()
  ;; DCL에서는 직접 그룹을 enable/disable 하기 어려우므로
  ;; 모드 상태를 글로벌 변수에 저장하고 프린트만 한다
  (if (= *dwf:mode* "sample")
    (princ "")  ; 샘플 모드 활성
    (princ "")  ; 수동 모드 활성
  )
)


;;; ────────────────────────────────────────────────────────────
;;; UI 헬퍼: 폴더 찾아보기 (BrowseForFolder 시뮬레이션)
;;; ────────────────────────────────────────────────────────────
(defun dwf-ui-browse-folder ( / shell folder-obj folder-path)
  ;; Shell.Application 의 BrowseForFolder 사용
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
              (vlax-get-property folder-obj 'Self)
              'Path))
          ;; 마지막 \ 제거
          (if (= (substr folder-path (strlen folder-path)) "\\")
            (setq folder-path
              (substr folder-path 1 (1- (strlen folder-path)))))
          (setq *dwf:folder* folder-path)
          (set_tile "ed_folder" folder-path)
        )
      )
      (vlax-release-object shell)
    )
  )
)


;;; ────────────────────────────────────────────────────────────
;;; UI 헬퍼: 미리보기 (감지 결과 카운트)
;;; ────────────────────────────────────────────────────────────
(defun dwf-ui-preview ( / doc borders n)
  (setq doc (vla-get-activedocument (vlax-get-acad-object)))
  (setq borders (dwf-detect-borders doc))
  (setq n (if borders (length borders) 0))
  (set_tile "txt_count"
    (strcat "감지된 테두리: " (itoa n) "개"))
  (setq *dwf:borders* borders)
)


;;; ────────────────────────────────────────────────────────────
;;; UI 헬퍼: 다이얼로그 닫기 전 값 저장
;;; ────────────────────────────────────────────────────────────
(defun dwf-ui-save-values ()
  (setq *dwf:folder*   (get_tile "ed_folder"))
  (setq *dwf:prefix*   (get_tile "ed_prefix"))
  (setq *dwf:plotter*  (get_tile "ed_plotter"))
  (setq *dwf:min-size* (atoi (get_tile "ed_min_size")))
  (setq *dwf:aci*      (atoi (get_tile "ed_aci")))
  (setq *dwf:rgb-r*    (atoi (get_tile "ed_r")))
  (setq *dwf:rgb-g*    (atoi (get_tile "ed_g")))
  (setq *dwf:rgb-b*    (atoi (get_tile "ed_b")))
)


;;; ────────────────────────────────────────────────────────────
;;; 샘플 선택: 사용자가 클릭한 객체에서 속성 추출
;;; ────────────────────────────────────────────────────────────
(defun dwf-pick-sample (doc / ent obj color-val layer-name
                             true-color r g b)

  (princ "\n테두리 사각형 하나를 클릭하세요...")
  (setq ent (car (entsel "\n테두리 선택: ")))

  (if (null ent)
    (progn
      (princ "\n  선택 취소됨.")
      (return)
    )
  )

  (setq obj (vlax-ename->vla-object ent))

  ;; 레이어명 추출
  (setq layer-name (vla-get-layer obj))
  (setq *dwf:sample-layer* layer-name)

  ;; 색상 추출 시도
  ;; 1) TrueColor (RGB) 시도
  (setq true-color
    (vl-catch-all-apply 'vla-get-truecolor (list obj)))

  (if (and (not (vl-catch-all-error-p true-color))
           true-color
           (/= (vla-get-colormethod true-color) acColorMethodByACI))
    (progn
      ;; RGB 값 추출
      (setq r (vla-get-red   true-color))
      (setq g (vla-get-green true-color))
      (setq b (vla-get-blue  true-color))
      (setq *dwf:sample-color* (list r g b))
      (setq *dwf:color-type* "rgb")
      (setq *dwf:rgb-r* r)
      (setq *dwf:rgb-g* g)
      (setq *dwf:rgb-b* b)
      (princ (strcat "\n  색상 감지: RGB(" (itoa r) "," (itoa g) "," (itoa b) ")"))
    )
    (progn
      ;; ACI 색상
      (setq color-val
        (vl-catch-all-apply 'vla-get-color (list obj)))
      (if (and (not (vl-catch-all-error-p color-val))
               (numberp color-val))
        (progn
          (setq *dwf:sample-color* color-val)
          (setq *dwf:color-type* "aci")
          (setq *dwf:aci* color-val)
          (princ (strcat "\n  색상 감지: ACI " (itoa color-val)))
        )
        (progn
          ;; DXF에서 직접 읽기
          (setq color-val (cdr (assoc 62 (entget ent))))
          (if color-val
            (progn
              (setq *dwf:sample-color* color-val)
              (setq *dwf:color-type* "aci")
              (setq *dwf:aci* color-val)
              (princ (strcat "\n  색상 감지 (DXF): ACI " (itoa color-val)))
            )
            (progn
              (setq *dwf:sample-color* 256)  ; ByLayer
              (princ "\n  색상: ByLayer (레이어 색상 상속)")
            )
          )
        )
      )
    )
  )

  (princ (strcat "\n  레이어: " layer-name))
  (setq *dwf:sample-ent* ent)
)


;;; ────────────────────────────────────────────────────────────
;;; 테두리 감지: 설정에 따라 매칭하는 폴리라인 수집
;;; ────────────────────────────────────────────────────────────
(defun dwf-detect-borders (doc / ss filter-list
                                i ent obj
                                pt-min pt-max
                                borders
                                match-p
                                color-val
                                true-color r g b)

  ;; 기본 필터: LWPOLYLINE
  (setq filter-list '((0 . "LWPOLYLINE")))

  ;; 닫힌 폴리라인만
  (if *dwf:closed-only*
    (setq filter-list (append filter-list '((70 . 1))))
  )

  ;; 모드별 추가 필터
  (cond
    ;; ── 샘플 모드 ──
    ((= *dwf:mode* "sample")
     (if *dwf:sample-color*
       (cond
         ;; ACI 색상으로 필터
         ((numberp *dwf:sample-color*)
          (if (/= *dwf:sample-color* 256)  ; ByLayer가 아닌 경우
            (setq filter-list
              (append filter-list
                (list (cons 62 *dwf:sample-color*))))
          )
         )
         ;; RGB인 경우 전체 가져와서 후처리
         ((listp *dwf:sample-color*)
          nil  ; 추가 필터 없이 후처리
         )
       )
     )
     ;; 레이어 매칭
     (if (and *dwf:layer-match* *dwf:sample-layer*)
       (setq filter-list
         (append filter-list
           (list (cons 8 *dwf:sample-layer*))))
     )
    )

    ;; ── 수동 모드 ──
    ((= *dwf:mode* "manual")
     (if (= *dwf:color-type* "aci")
       (setq filter-list
         (append filter-list
           (list (cons 62 *dwf:aci*))))
       ;; RGB일 경우 전체 가져와서 후처리
     )
     ;; 레이어 매칭 (수동 모드에서도 유효)
     (if (and *dwf:layer-match* *dwf:sample-layer*)
       (setq filter-list
         (append filter-list
           (list (cons 8 *dwf:sample-layer*))))
     )
    )
  )

  ;; 선택 세트 생성
  (setq ss (ssget "X" filter-list))

  (if (null ss)
    (progn
      (princ "\n  필터 조건에 맞는 객체를 찾지 못했습니다.")
      (return nil)
    )
  )

  ;; 결과 수집
  (setq borders '())
  (setq i 0)
  (repeat (sslength ss)
    (setq ent (ssname ss i))
    (setq obj (vlax-ename->vla-object ent))

    (setq match-p T)

    ;; RGB 색상 필터 (후처리)
    (if (and (= *dwf:mode* "sample")
             (listp *dwf:sample-color*))
      (progn
        (setq true-color
          (vl-catch-all-apply 'vla-get-truecolor (list obj)))
        (if (not (vl-catch-all-error-p true-color))
          (progn
            (setq r (vla-get-red   true-color))
            (setq g (vla-get-green true-color))
            (setq b (vla-get-blue  true-color))
            (if (not (and (= r (car   *dwf:sample-color*))
                          (= g (cadr  *dwf:sample-color*))
                          (= b (caddr *dwf:sample-color*))))
              (setq match-p nil)
            )
          )
          (setq match-p nil)
        )
      )
    )

    ;; 수동 RGB 모드 후처리
    (if (and (= *dwf:mode* "manual")
             (= *dwf:color-type* "rgb"))
      (progn
        (setq true-color
          (vl-catch-all-apply 'vla-get-truecolor (list obj)))
        (if (not (vl-catch-all-error-p true-color))
          (progn
            (setq r (vla-get-red   true-color))
            (setq g (vla-get-green true-color))
            (setq b (vla-get-blue  true-color))
            (if (not (and (= r *dwf:rgb-r*)
                          (= g *dwf:rgb-g*)
                          (= b *dwf:rgb-b*)))
              (setq match-p nil)
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

          (if (and (> (- (car  pt-max) (car  pt-min)) *dwf:min-size*)
                   (> (- (cadr pt-max) (cadr pt-min)) *dwf:min-size*))
            (setq borders (cons (list pt-min pt-max) borders))
          )
        )
      )
    )

    (setq i (1+ i))
  )

  borders
)


;;; ────────────────────────────────────────────────────────────
;;; 정렬: 위→아래 (Y 내림), 같은 행은 좌→우 (X 오름)
;;; ────────────────────────────────────────────────────────────
(defun dwf-sort-borders (borders / row-threshold)

  ;; 행 구분 임계값: 첫 블록 높이의 40%
  (setq row-threshold
    (if borders
      (* 0.4 (abs (- (cadr (cadr (car borders)))
                     (cadr (car  (car borders))))))
      5000))

  (vl-sort borders
    (function
      (lambda (a b)
        (let* ((ay (cadr (cadr a)))
               (by (cadr (cadr b)))
               (ax (car  (car  a)))
               (bx (car  (car  b))))
          (if (> (abs (- ay by)) row-threshold)
            (> ay by)
            (< ax bx)
          )
        )
      )
    )
  )
)


;;; ────────────────────────────────────────────────────────────
;;; 플롯: Window 영역 → DWF 파일
;;; ────────────────────────────────────────────────────────────
(defun dwf-plot-window (doc layout pt-min pt-max dwf-path
                         / plot-obj lo-name win-min win-max)

  (setq plot-obj (vla-get-plot doc))
  (setq lo-name  (vla-get-name layout))

  ;; 좌표 → SafeArray
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
      plot-obj
      lo-name
      dwf-path
      *dwf:plotter*       ; 사용자 지정 플로터
      "_NONE_"
      acPlotWindow
      :vlax-true
      acScaleToFit
      ac0degrees
      :vlax-true
      win-min
      win-max
    )
  )
)


;;; ────────────────────────────────────────────────────────────
;;; 텍스트 모드 폴백 (DCL 없을 때)
;;; ────────────────────────────────────────────────────────────
(defun export-dwf-borders-textmode (doc / mode aci-val
                                         ss i ent obj
                                         pt-min pt-max
                                         borders sorted-borders
                                         layout cnt dwf-path)

  (princ "\n\n[텍스트 모드] DCL 파일 없이 실행합니다.")
  (princ "\n========================================\n")

  ;; 모드 선택
  (initget "Sample Manual")
  (setq mode
    (getkword "\n감지 방식 [Sample 선택/Manual 색상입력] <Sample>: "))
  (if (null mode) (setq mode "Sample"))

  (cond
    ;; 샘플 선택
    ((= mode "Sample")
     (dwf-pick-sample doc)
    )

    ;; 수동 입력
    ((= mode "Manual")
     (setq aci-val (getint "\nACI 색상 번호 입력 (1=빨강, 2=노랑 ...): "))
     (if aci-val
       (progn
         (setq *dwf:aci* aci-val)
         (setq *dwf:mode* "manual")
         (setq *dwf:color-type* "aci")
       )
     )
    )
  )

  ;; 폴더 입력
  (setq *dwf:folder*
    (getstring (strcat "\nDWF 저장 폴더 [" *dwf:folder* "]: ")))
  (if (= *dwf:folder* "")
    (setq *dwf:folder*
      (vl-filename-directory (vla-get-fullname doc)))
  )

  ;; 감지 실행
  (setq borders (dwf-detect-borders doc))

  (if (null borders)
    (progn (princ "\n[오류] 테두리를 찾을 수 없습니다.") (exit))
  )

  (princ (strcat "\n" (itoa (length borders)) "개 테두리 감지됨."))

  ;; 정렬 및 플롯
  (setq sorted-borders (dwf-sort-borders borders))
  (setq layout (vla-get-activelayout doc))

  (if (not (vl-file-directory-p *dwf:folder*))
    (vl-mkdir *dwf:folder*)
  )

  (setq cnt 1)
  (foreach border sorted-borders
    (setq pt-min (car  border))
    (setq pt-max (cadr border))
    (setq dwf-path (strcat *dwf:folder* "\\" "도면" (itoa cnt) ".dwf"))
    (princ (strcat "\n  플롯 [" (itoa cnt) "] → 도면" (itoa cnt) ".dwf"))
    (dwf-plot-window doc layout pt-min pt-max dwf-path)
    (setq cnt (1+ cnt))
  )

  (princ (strcat "\n\n✔ 완료! " (itoa (1- cnt)) "개 DWF 파일 생성됨\n"))
)


;;; ────────────────────────────────────────────────────────────
;;; 로드 메시지
;;; ────────────────────────────────────────────────────────────
(princ "\n[export_dwf_by_border.lsp 로드 완료]")
(princ "\n  명령어: EXPORT-DWF-BORDERS")
(princ "\n  기능: UI 다이얼로그를 통한 테두리 감지 & DWF 일괄 내보내기")
(princ)
