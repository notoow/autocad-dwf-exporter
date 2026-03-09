# AutoCAD Sheet Exporter

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![AutoCAD](https://img.shields.io/badge/AutoCAD-2015~2025-red.svg)](https://www.autodesk.com/products/autocad)
[![AutoLISP](https://img.shields.io/badge/AutoLISP-Visual%20LISP-green.svg)](#)

[한국어](#ko) | [English](#english)

---

<a id="ko"></a>
## 한국어

모델 공간의 테두리 객체를 감지해서 각 시트를 개별 `DWF` 또는 `PDF`로 내보내는 AutoLISP 스크립트입니다.
`INSERT` 블록 참조와 닫힌 `LWPOLYLINE` 테두리를 지원하며, 필요하면 `PDF + DWF`를 한 번에 둘 다 생성할 수 있습니다.

### 주요 기능

- `EXPORT-SHEETS` 기본 명령, `EXPORT-DWF` 호환 별칭 유지
- `INSERT` + 닫힌 `LWPOLYLINE` 동시 감지
- 샘플 테두리 1개를 클릭하면 레이어/ACI를 자동 추출
- 샘플 선택 직후 같은 조건의 감지 개수를 자동 계산해서 미리보기 표시
- 출력 형식:
  - `DWF`
  - `PDF`
  - `PDF + DWF`
- 출력 범위:
  - `테두리 기준`
  - `내부 내용 기준 크롭`
- 용지 기본값은 `자동 맞춤`
- 특수 상황에서는 플로터에 등록된 `사용자정의/커스텀 용지명`을 정확히 직접 지정 가능
- CTB 기본값은 `none`, 필요 시 정확한 스타일명 직접 지정 가능
- AutoCAD 2016 이상은 `ActiveX PlotToFile`, 실패 시 자동으로 `-PLOT` 폴백
- AutoCAD 2015는 `-PLOT` 명령 경로 사용

### 배포 시 필요한 파일

실사용 기준으로는 아래 2개만 있으면 됩니다.

- `export_dwf_main.lsp`
- `export_dwf_ui.dcl`

대상 `.dwg` 파일과 같은 폴더에 두는 것을 권장합니다.

`encode_euckr.py`, `.vscode/settings.json`, `README.md`는 개발/관리용입니다.

### 빠른 시작

1. `export_dwf_main.lsp` 와 `export_dwf_ui.dcl` 을 대상 `.dwg` 와 같은 폴더에 둡니다.
2. AutoCAD에서 `APPLOAD` 실행
3. `export_dwf_main.lsp` 로드
4. 명령행에 `EXPORT-SHEETS` 입력

호환용으로 `EXPORT-DWF`도 계속 동작합니다.

### 기본 동작

- 용지를 비워두거나 `자동` 상태로 두면 각 테두리 크기에 가장 가까운 용지를 자동 선택합니다.
- `PDF + DWF`를 고르면 시트마다 `도면1.dwf`, `도면1.pdf` 식으로 둘 다 생성합니다.
- `플롯 스타일`을 비워두거나 기본 상태로 두면 `none` 으로 처리합니다.
- `특수/사용자정의 용지명`은 표준 용지가 아닌, 플로터에 등록된 특정 용지명을 강제로 써야 할 때 사용합니다.

### DCL 없이도 사용 가능

`export_dwf_ui.dcl` 을 찾지 못하면 텍스트 모드로 자동 전환됩니다.
텍스트 모드에서도 감지 방식, 출력 형식, 크롭 모드, 저장 폴더를 입력해서 실행할 수 있습니다.

### 인코딩 작업 흐름

배포용 `.lsp`, `.dcl` 파일은 AutoCAD 호환성을 위해 `CP949` 기준으로 관리합니다.
반면 `README.md` 는 일반적인 GitHub 표시를 위해 `UTF-8` 입니다.

UTF-8로 수정한 뒤 배포용으로 다시 변환하려면:

```bash
python encode_euckr.py export_dwf_main.lsp
python encode_euckr.py export_dwf_ui.dcl
```

덮어쓰기 변환 시 `.utf8.bak` 백업이 자동 생성됩니다.

### 요구 사항

- AutoCAD 2015 ~ 2025
- `DWF6 ePlot.pc3` 또는 `DWG To PDF.pc3`
- UI 사용 시 `export_dwf_ui.dcl` 이 DWG와 같은 폴더에 있거나 AutoCAD 검색 경로에 포함되어 있어야 함

### 최근 반영 사항

- 자동 용지 맞춤 기본값 적용
- `EXPORT-SHEETS` 명령 추가
- 샘플 선택 후 감지 개수 자동 미리보기
- model space 기준 감지 강화
- `PDF + DWF` 동시 출력 추가
- 특수/사용자정의 용지명 직접 지정 안내 개선

---

<a id="english"></a>
## English

AutoLISP utility for detecting sheet borders in model space and exporting each sheet as an individual `DWF` or `PDF` file.
It supports both `INSERT` block references and closed `LWPOLYLINE` borders, and can optionally export both `PDF + DWF` in one batch run.

### Features

- Primary command: `EXPORT-SHEETS`
- Backward-compatible alias: `EXPORT-DWF`
- Detects both `INSERT` and closed `LWPOLYLINE` borders
- Sample-pick mode automatically captures layer and ACI color
- Automatically previews matching border count after sample selection
- Output modes:
  - `DWF`
  - `PDF`
  - `PDF + DWF`
- Crop modes:
  - `Border`
  - `Content`
- Default paper mode is `Auto Fit`
- Exact custom paper names can be entered for special plotter-specific cases
- Default CTB is `none`
- AutoCAD 2016+ uses ActiveX with automatic `-PLOT` fallback
- AutoCAD 2015 uses `-PLOT`

### Files Required For Deployment

Only these two files are required for normal use:

- `export_dwf_main.lsp`
- `export_dwf_ui.dcl`

Place them in the same folder as the target `.dwg` whenever possible.

### Quick Start

1. Put `export_dwf_main.lsp` and `export_dwf_ui.dcl` next to your target drawing.
2. Run `APPLOAD` in AutoCAD.
3. Load `export_dwf_main.lsp`.
4. Run `EXPORT-SHEETS`.

`EXPORT-DWF` is still available as a compatibility alias.

### Plot Behavior

- If paper is left at `Auto`, the script selects the closest available paper for each detected border.
- If `PDF + DWF` is selected, each sheet is exported twice, for example `Sheet1.dwf` and `Sheet1.pdf`.
- If plot style is left empty/default, it behaves as `none`.
- Manual paper input is intended for exact custom paper names already registered in the target plotter.

### Encoding Workflow

Distributable `.lsp` and `.dcl` files are kept in `CP949` for Korean AutoCAD compatibility.
This `README.md` stays in `UTF-8` for GitHub readability.

To convert edited source files back to CP949:

```bash
python encode_euckr.py export_dwf_main.lsp
python encode_euckr.py export_dwf_ui.dcl
```

Overwrite conversion automatically creates `.utf8.bak` backups.

### Requirements

- AutoCAD 2015 ~ 2025
- `DWF6 ePlot.pc3` or `DWG To PDF.pc3`
- For UI mode, `export_dwf_ui.dcl` must be in the same folder as the drawing or in the AutoCAD support search path

---

## License

MIT License
