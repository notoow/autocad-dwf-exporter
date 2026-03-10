// ============================================================
// export_dwf_ui.dcl  v5
// DXF/PDF/DWF 일괄 내보내기 설정 다이얼로그
// AutoCAD 2015 이상 호환
// ============================================================

export_dwf_dialog : dialog {
  label = "DXF/PDF/DWF 일괄 내보내기  v5";
  initial_focus = "btn_pick";

  // ── 감지 방식 ──
  : boxed_column {
    label = "테두리 감지 방식";
    : radio_row {
      : radio_button {
        key   = "rb_sample";
        label = "샘플 클릭 (테두리 하나를 직접 클릭)";
        value = "1";
      }
      : radio_button {
        key   = "rb_layer";
        label = "레이어 이름으로 직접 입력";
        value = "0";
      }
    }
    : row {
      : button {
        key         = "btn_pick";
        label       = "테두리 샘플 선택";
        width       = 20;
        fixed_width = true;
      }
      : text { key = "txt_sample"; label = "(선택 안 됨)"; width = 38; }
    }
    : row {
      : text     { label = "레이어명:"; width = 10; }
      : edit_box { key = "ed_layer"; edit_width = 22; value = ""; }
      : text     { label = "  ACI:"; width = 6; }
      : edit_box { key = "ed_aci";   edit_width = 6;  value = ""; }
    }
    : text {
      label = "  * ACI 입력 시 해당 색상만 감지 / 비워두면 레이어 전체";
    }
  }

  // ── 출력 형식 ──
  : boxed_column {
    label = "출력 형식";
    : row {
      : text       { label = "형식:"; width = 10; }
      : popup_list { key = "cb_format"; width = 30; }
    }
    : text {
      label = "  * 기본은 DXF / 복수 형식은 한 번에 순차 생성";
    }
  }

  // ── 출력 설정 ──
  : boxed_column {
    label = "출력 설정";
    : row {
      : text     { label = "저장 폴더:";  width = 10; }
      : edit_box { key = "ed_folder";  edit_width = 36; value = ""; }
      : button   { key = "btn_browse"; label = "찾기..."; width = 9; fixed_width = true; }
    }
    : row {
      : text     { label = "파일 접두사:"; width = 12; }
      : edit_box { key = "ed_prefix";  edit_width = 16; value = "도면"; }
      : text     { label = "  (도면1.dxf / 도면1.pdf / 도면1.dwf ...)"; }
    }
    : row {
      : text     { label = "최소 크기:"; width = 10; }
      : edit_box { key = "ed_minsize"; edit_width = 10; value = "500"; }
      : text     { label = "  (이하 무시, 도면 단위)"; }
    }
    : row {
      : text       { label = "출력 범위:"; width = 10; }
      : popup_list { key = "cb_crop_mode"; width = 22; }
      : text       { label = "  (테두리 / 내용 크롭)"; }
    }
    : text {
      label = "  * 내용 크롭은 블록/내부 객체 bbox를 우선 사용, 실패 시 테두리 기준";
    }
  }

  // ── 플롯 옵션 ──
  : boxed_column {
    label = "플롯 옵션";
    : row {
      : text       { label = "용지 크기:"; width = 10; }
      : popup_list { key = "cb_paper"; width = 30; }
      : edit_box   { key = "ed_paper"; edit_width = 16; value = "자동"; }
    }
    : text         { label = "  * DXF 전용일 때는 사용 안 함 / PDF·DWF 포함 시 자동 맞춤 또는 정확한 용지명 입력"; }
    : row {
      : text       { label = "플롯 스타일:"; width = 10; }
      : popup_list { key = "cb_ctb"; width = 30; }
      : edit_box   { key = "ed_ctb"; edit_width = 16; value = "none"; }
    }
    : text         { label = "  * DXF 전용일 때는 사용 안 함 / PDF·DWF 포함 시 정확한 스타일명 입력 가능"; }
  }

  // ── 미리보기 ──
  : boxed_column {
    label = "미리보기";
    : row {
      : button { key = "btn_preview"; label = "감지 실행"; width = 14; fixed_width = true; }
      : text   { key = "txt_count";  label = "감지된 개수: -"; width = 30; }
    }
  }

  // ── 버튼 ──
  : row {
    : spacer { width = 10; }
    : button {
      key         = "accept";
      label       = "내보내기 시작";
      is_default  = true;
      width       = 16;
      fixed_width = true;
    }
    : button {
      key         = "cancel";
      label       = "취소";
      is_cancel   = true;
      width       = 10;
      fixed_width = true;
    }
  }
}
