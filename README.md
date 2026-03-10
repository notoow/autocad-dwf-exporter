# AutoCAD DXF/PDF/DWF Batch Exporter for Sheet Borders

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![AutoCAD](https://img.shields.io/badge/AutoCAD-2015~2025-red.svg)](https://www.autodesk.com/products/autocad)
[![AutoLISP](https://img.shields.io/badge/AutoLISP-Visual%20LISP-green.svg)](#)

[한국어](#ko) | [English](#english)

---

<a id="ko"></a>
## 한국어

AutoCAD에서 모델 공간 테두리를 감지해서 시트별로 `DXF`, `PDF`, `DWF`를 일괄 저장하는 AutoLISP 도구입니다.
지금 기준 기본 출력은 `DXF`이고, 필요하면 `PDF`, `DWF`, `DXF + PDF`, `DXF + DWF`, `PDF + DWF`, `DXF + PDF + DWF`까지 한 번에 순차 생성할 수 있습니다.

### 검색 키워드

- `AutoCAD DXF 일괄 추출`
- `AutoCAD DXF export`
- `AutoCAD PDF 일괄 출력`
- `AutoCAD DWF export`
- `AutoCAD batch plot`
- `AutoCAD sheet export`
- `AutoCAD Blender DXF`
- `AutoCAD 도면 낱장 저장`

### 주요 기능

- 기본 명령: `EXPORT-SMART`
- `DXF` 기본 출력
- 지원 형식:
  - `DXF`
  - `PDF`
  - `DWF`
  - `DXF + PDF`
  - `DXF + DWF`
  - `PDF + DWF`
  - `DXF + PDF + DWF`
- `INSERT` 블록 참조 + 닫힌 `LWPOLYLINE` 테두리 감지
- 샘플 테두리 1개 클릭 시 레이어/ACI 자동 추출
- 샘플 선택 직후 같은 조건의 감지 개수 자동 미리보기
- 출력 범위:
  - `테두리 기준`
  - `내부 내용 기준 크롭`
- 용지 기본값 `자동 맞춤`
- CTB 기본값 `none`
- 특수 상황에서는 플로터에 등록된 `사용자정의/커스텀 용지명` 직접 지정 가능
- AutoCAD 2016+:
  - `PDF/DWF`는 ActiveX PlotToFile
  - 실패 시 `-PLOT` 자동 폴백
- AutoCAD 2015:
  - `PDF/DWF`는 `-PLOT`
- `DXF`:
  - `WBLOCK + SaveAs` 기반 낱장 내보내기

### 배포 시 필요한 파일

실사용 기준으로는 아래 2개만 있으면 됩니다.

- `export_dwf_main.lsp`
- `export_dwf_ui.dcl`

대상 `.dwg` 와 같은 폴더에 두는 것을 권장합니다.

개발/관리용 파일:

- `encode_euckr.py`
- `README.md`
- `docs/`
- `.vscode/`

### 빠른 시작

1. `export_dwf_main.lsp` 와 `export_dwf_ui.dcl` 을 대상 `.dwg` 와 같은 폴더에 둡니다.
2. AutoCAD에서 `APPLOAD` 실행
3. `export_dwf_main.lsp` 로드
4. 명령행에 `EXPORT-SMART` 입력

### 기본 동작

- 아무 형식도 따로 건드리지 않으면 `DXF`로 저장합니다.
- `DXF`만 선택한 경우 `용지 크기`와 `플롯 스타일`은 사용되지 않습니다.
- `PDF/DWF`가 포함된 형식을 고르면 각 테두리 크기에 가장 가까운 용지를 자동 선택합니다.
- `플롯 스타일`을 비워두거나 기본 상태로 두면 `none` 으로 처리합니다.
- `DXF + PDF` 같은 복수 형식을 고르면 시트마다 확장자별 파일이 각각 생성됩니다.
  - 예: `도면1.dxf`, `도면1.pdf`
- `특수/사용자정의 용지명`은 표준 용지가 아닌, 플로터에 등록된 특정 용지명을 강제로 써야 할 때 사용합니다.

### DCL 없이도 사용 가능

`export_dwf_ui.dcl` 을 찾지 못하면 텍스트 모드로 자동 전환됩니다.
텍스트 모드에서도 감지 방식, 출력 형식, 크롭 모드, 저장 폴더를 입력해서 실행할 수 있습니다.

### 인코딩 작업 흐름

배포용 `.lsp`, `.dcl` 파일은 AutoCAD 호환성을 위해 `CP949` 기준으로 관리합니다.
`README.md` 와 `docs/` 는 GitHub 표시를 위해 `UTF-8` 입니다.

UTF-8로 수정한 뒤 배포용으로 다시 변환하려면:

```bash
python encode_euckr.py export_dwf_main.lsp
python encode_euckr.py export_dwf_ui.dcl
```

덮어쓰기 변환 시 `.utf8.bak` 백업이 자동 생성됩니다.

### GitHub Pages / Social Preview

- Pages 랜딩 페이지: `https://notoow.github.io/autocad-dwf-exporter/`
- 저장소 social preview 이미지: `assets/social-preview.png`
- GitHub 저장소 `Settings > Social preview` 에서 업로드하면 링크 미리보기에 반영됩니다.

### 요구 사항

- AutoCAD 2015 ~ 2025
- `DWG To PDF.pc3` 또는 `DWF6 ePlot.pc3`
- UI 사용 시 `export_dwf_ui.dcl` 이 DWG와 같은 폴더에 있거나 AutoCAD 검색 경로에 포함되어 있어야 함

### 최근 반영 사항

- 기본 출력 형식을 `DXF` 로 전환
- `DXF + PDF + DWF` 포함 다중 형식 조합 지원
- 자동 용지 맞춤 기본값 적용
- 샘플 선택 후 감지 개수 자동 미리보기
- model space 기준 감지 강화
- GitHub Pages 랜딩 페이지 및 social preview 추가

---

<a id="english"></a>
## English

AutoLISP utility for exporting model-space sheet borders as per-sheet `DXF`, `PDF`, and `DWF` files.
`DXF` is now the default output, and the tool also supports `PDF`, `DWF`, `DXF + PDF`, `DXF + DWF`, `PDF + DWF`, and `DXF + PDF + DWF` in a single run.

### Search Keywords

- `AutoCAD DXF batch export`
- `AutoCAD DXF export`
- `AutoCAD PDF batch export`
- `AutoCAD DWF export`
- `AutoCAD batch plot`
- `AutoCAD sheet export`
- `AutoCAD Blender DXF`
- `AutoCAD border detection export`

### Features

- Primary command: `EXPORT-SMART`
- `DXF` is the default output mode
- Output modes:
  - `DXF`
  - `PDF`
  - `DWF`
  - `DXF + PDF`
  - `DXF + DWF`
  - `PDF + DWF`
  - `DXF + PDF + DWF`
- Detects both `INSERT` and closed `LWPOLYLINE` borders
- Sample-pick mode automatically captures layer and ACI color
- Automatically previews matching border count after sample selection
- Crop modes:
  - `Border`
  - `Content`
- Default paper mode is `Auto Fit`
- Default CTB is `none`
- Exact custom paper names can be entered for special plotter-specific cases
- AutoCAD 2016+:
  - `PDF/DWF` uses ActiveX with automatic `-PLOT` fallback
- AutoCAD 2015:
  - `PDF/DWF` uses `-PLOT`
- `DXF` export uses `WBLOCK + SaveAs`

### Files Required For Deployment

Only these two files are required for normal use:

- `export_dwf_main.lsp`
- `export_dwf_ui.dcl`

Place them next to the target `.dwg` whenever possible.

### Quick Start

1. Put `export_dwf_main.lsp` and `export_dwf_ui.dcl` next to the drawing.
2. Run `APPLOAD` in AutoCAD.
3. Load `export_dwf_main.lsp`.
4. Run `EXPORT-SMART`.

### Default Behavior

- If you do nothing, the tool exports `DXF`.
- In `DXF`-only mode, paper and CTB settings are ignored.
- If a mode includes `PDF` or `DWF`, the script chooses the closest available paper for each border.
- If plot style is left empty/default, it behaves as `none`.
- Multi-format modes export one file per selected extension.
  - Example: `Sheet1.dxf`, `Sheet1.pdf`
- Manual paper input is intended for exact custom paper names already registered in the plotter.

### Encoding Workflow

Distributable `.lsp` and `.dcl` files are kept in `CP949` for Korean AutoCAD compatibility.
This `README.md` and the `docs/` site stay in `UTF-8` for GitHub readability.

To convert edited source files back to CP949:

```bash
python encode_euckr.py export_dwf_main.lsp
python encode_euckr.py export_dwf_ui.dcl
```

Overwrite conversion automatically creates `.utf8.bak` backups.

### Requirements

- AutoCAD 2015 ~ 2025
- `DWG To PDF.pc3` or `DWF6 ePlot.pc3`
- For UI mode, `export_dwf_ui.dcl` must be in the same folder as the drawing or in the AutoCAD support search path

---

## License

MIT License
