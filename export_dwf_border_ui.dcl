// ============================================================
// export_dwf_border_ui.dcl
// DWF 테두리 내보내기 - 설정 다이얼로그
// ============================================================

dwf_border_dialog : dialog {
  label = "DWF 일괄 내보내기 - 테두리 설정";
  initial_focus = "btn_pick";

  // ── 감지 방식 선택 ──
  : boxed_column {
    label = "테두리 감지 방식";

    : radio_row {
      : radio_button {
        key = "rb_sample";
        label = "샘플 선택 (테두리 하나를 클릭하여 자동 감지)";
        value = "1";
      }
      : radio_button {
        key = "rb_manual";
        label = "색상값 직접 입력";
        value = "0";
      }
    }
  }

  // ── 샘플 선택 영역 ──
  : boxed_column {
    key = "grp_sample";
    label = "샘플 선택";

    : row {
      : button {
        key = "btn_pick";
        label = "테두리 샘플 선택 ▶";
        width = 25;
        fixed_width = true;
      }
      : text {
        key = "txt_sample_info";
        label = "(선택된 샘플 없음)";
        width = 40;
      }
    }

    : row {
      : text { label = "감지된 색상:"; width = 12; }
      : text { key = "txt_detected_color"; label = "-"; width = 20; }
      : text { label = "레이어:"; width = 8; }
      : text { key = "txt_detected_layer"; label = "-"; width = 20; }
    }
  }

  // ── 수동 색상 입력 영역 ──
  : boxed_column {
    key = "grp_manual";
    label = "색상값 입력";

    : radio_row {
      : radio_button {
        key = "rb_aci";
        label = "ACI 색상 번호";
        value = "1";
      }
      : radio_button {
        key = "rb_rgb";
        label = "RGB 값";
        value = "0";
      }
    }

    : row {
      : text { label = "ACI (1~255):"; width = 14; }
      : edit_box {
        key = "ed_aci";
        edit_width = 6;
        value = "1";
      }
      : spacer { width = 4; }
      : text { label = "* 1=빨강, 2=노랑, 3=초록, 4=파랑, 5=마젠타"; }
    }

    : row {
      : text { label = "R (0~255):"; width = 14; }
      : edit_box { key = "ed_r"; edit_width = 6; value = "255"; }
      : text { label = "G:"; width = 4; }
      : edit_box { key = "ed_g"; edit_width = 6; value = "0"; }
      : text { label = "B:"; width = 4; }
      : edit_box { key = "ed_b"; edit_width = 6; value = "0"; }
    }
  }

  // ── 필터 옵션 ──
  : boxed_column {
    label = "필터 옵션";

    : row {
      : toggle {
        key = "chk_closed";
        label = "닫힌 폴리라인만 (Closed)";
        value = "1";
      }
      : spacer { width = 4; }
      : toggle {
        key = "chk_layer_match";
        label = "같은 레이어만 매칭";
        value = "0";
      }
    }

    : row {
      : text { label = "최소 크기 (단위):"; width = 18; }
      : edit_box {
        key = "ed_min_size";
        edit_width = 10;
        value = "100";
      }
      : text { label = "(이 크기 이하의 사각형은 무시)"; }
    }
  }

  // ── 출력 설정 ──
  : boxed_column {
    label = "출력 설정";

    : row {
      : text { label = "저장 폴더:"; width = 10; }
      : edit_box {
        key = "ed_folder";
        edit_width = 45;
        value = "";
      }
      : button {
        key = "btn_browse";
        label = "찾아보기...";
        width = 12;
        fixed_width = true;
      }
    }

    : row {
      : text { label = "파일명 접두사:"; width = 14; }
      : edit_box {
        key = "ed_prefix";
        edit_width = 20;
        value = "도면";
      }
      : text { label = "(예: 도면1.dwf, 도면2.dwf ...)"; }
    }

    : row {
      : text { label = "플로터:"; width = 10; }
      : edit_box {
        key = "ed_plotter";
        edit_width = 30;
        value = "DWF6 ePlot.pc3";
      }
    }
  }

  // ── 감지 결과 미리보기 ──
  : boxed_column {
    label = "감지 결과";

    : row {
      : button {
        key = "btn_preview";
        label = "미리보기 (감지 실행) ▶";
        width = 25;
        fixed_width = true;
      }
      : text {
        key = "txt_count";
        label = "감지된 테두리: 0개";
        width = 30;
      }
    }
  }

  // ── 확인/취소 ──
  : row {
    : spacer { width = 20; }
    : button {
      key = "accept";
      label = "DWF 내보내기 시작";
      is_default = true;
      width = 20;
      fixed_width = true;
    }
    : button {
      key = "cancel";
      label = "취소";
      is_cancel = true;
      width = 12;
      fixed_width = true;
    }
  }
}
