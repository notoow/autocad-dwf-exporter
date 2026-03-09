// ============================================================
// export_dwf_border_ui.dcl  v3
// DWF/PDF 테두리 내보내기 설정 다이얼로그
// ============================================================

dwf_border_dialog : dialog {
  label = "DWF/PDF 일괄 내보내기 - 테두리 설정";
  initial_focus = "btn_pick";

  // ── 감지 방식 ──
  : boxed_column {
    label = "테두리 감지 방식";
    : radio_row {
      : radio_button { key = "rb_sample"; label = "샘플 선택 (테두리 클릭)"; value = "1"; }
      : radio_button { key = "rb_manual"; label = "색상값 직접 입력"; value = "0"; }
    }
  }

  // ── 샘플 선택 ──
  : boxed_column {
    key = "grp_sample";
    label = "샘플 선택";
    : row {
      : button { key = "btn_pick"; label = "테두리 선택 ▶"; width = 20; fixed_width = true; }
      : text { key = "txt_sample_info"; label = "(선택 안 됨)"; width = 40; }
    }
    : row {
      : text { label = "색상:"; width = 8; }
      : text { key = "txt_detected_color"; label = "-"; width = 20; }
      : text { label = "레이어:"; width = 8; }
      : text { key = "txt_detected_layer"; label = "-"; width = 20; }
    }
  }

  // ── 색상 입력 ──
  : boxed_column {
    key = "grp_manual";
    label = "색상값 입력";
    : radio_row {
      : radio_button { key = "rb_aci"; label = "ACI 번호"; value = "1"; }
      : radio_button { key = "rb_rgb"; label = "RGB 값"; value = "0"; }
    }
    : row {
      : text { label = "ACI (1~255):"; width = 14; }
      : edit_box { key = "ed_aci"; edit_width = 6; value = "1"; }
      : spacer { width = 2; }
      : text { label = "1=빨강 2=노랑 3=초록 4=파랑 5=마젠타"; }
    }
    : row {
      : text { label = "R:"; width = 4; }
      : edit_box { key = "ed_r"; edit_width = 6; value = "255"; }
      : text { label = "G:"; width = 4; }
      : edit_box { key = "ed_g"; edit_width = 6; value = "0"; }
      : text { label = "B:"; width = 4; }
      : edit_box { key = "ed_b"; edit_width = 6; value = "0"; }
    }
  }

  // ── 출력 형식 (신규) ──
  : boxed_column {
    label = "출력 형식";
    : radio_row {
      : radio_button { key = "rb_dwf"; label = "DWF (DWF6 ePlot.pc3)"; value = "1"; }
      : radio_button { key = "rb_pdf"; label = "PDF (DWG To PDF.pc3)"; value = "0"; }
    }
  }

  // ── 필터 옵션 ──
  : boxed_column {
    label = "필터 옵션";
    : row {
      : toggle { key = "chk_closed"; label = "닫힌 폴리라인만"; value = "1"; }
      : spacer { width = 4; }
      : toggle { key = "chk_layer_match"; label = "같은 레이어만"; value = "0"; }
    }
    : row {
      : text { label = "최소 크기:"; width = 10; }
      : edit_box { key = "ed_min_size"; edit_width = 10; value = "100"; }
      : text { label = "(이하 무시)"; }
    }
  }

  // ── 출력 설정 ──
  : boxed_column {
    label = "출력 설정";
    : row {
      : text { label = "폴더:"; width = 6; }
      : edit_box { key = "ed_folder"; edit_width = 42; value = ""; }
      : button { key = "btn_browse"; label = "찾기..."; width = 10; fixed_width = true; }
    }
    : row {
      : text { label = "접두사:"; width = 8; }
      : edit_box { key = "ed_prefix"; edit_width = 18; value = "도면"; }
      : text { label = "(예: 도면1.dwf)"; }
    }
    : row {
      : text { label = "플로터:"; width = 8; }
      : edit_box { key = "ed_plotter"; edit_width = 30; value = "DWF6 ePlot.pc3"; }
    }
  }

  // ── 감지 결과 ──
  : boxed_column {
    label = "미리보기";
    : row {
      : button { key = "btn_preview"; label = "감지 실행 ▶"; width = 18; fixed_width = true; }
      : text { key = "txt_count"; label = "감지: 0개"; width = 25; }
    }
  }

  // ── 버튼 ──
  : row {
    : spacer { width = 15; }
    : button { key = "accept"; label = "내보내기 시작"; is_default = true; width = 18; fixed_width = true; }
    : button { key = "cancel"; label = "취소"; is_cancel = true; width = 10; fixed_width = true; }
  }
}
