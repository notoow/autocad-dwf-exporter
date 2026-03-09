# AutoCAD DWF/PDF Exporter

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![AutoCAD](https://img.shields.io/badge/AutoCAD-2015~2025-red.svg)](https://www.autodesk.com/products/autocad)
[![AutoLISP](https://img.shields.io/badge/AutoLISP-Visual%20LISP-green.svg)](#)

[한국어](#한국어) | [English](#english)

---

<a name="한국어"></a>
# 한국어

AutoCAD 도면에서 블록참조(INSERT) 및 폴리라인(LWPOLYLINE) 테두리를 자동 감지하여 각각을 개별 DWF 또는 PDF 파일로 일괄 내보내는 AutoLISP 스크립트입니다.

## 주요 기능

- **DWF / PDF 출력 형식 선택** (DWF6 ePlot / DWG To PDF)
- **INSERT(블록참조) + LWPOLYLINE(폴리라인) 동시 감지**, 중복 자동 제거
- **샘플 클릭**: 테두리 하나를 클릭하면 레이어/색상 자동 추출
- **ACI 색상 필터**: 특정 색상 객체만 선별 감지
- **DCL 다이얼로그 UI** (폴더 찾기, 미리보기, 필터 설정)
- DCL 없이도 **텍스트 모드**로 실행 가능
- 위→아래, 좌→우 **자동 정렬** (평균 높이 기반 행 구분)

## 플롯 엔진

버전에 따라 자동으로 최적의 방식을 선택합니다.

| AutoCAD 버전 | 방식 | 비고 |
|-------------|------|------|
| R21+ (2016~2025) | ActiveX PlotToFile | `vlax-get-property doc 'Plot` 사용, 레이아웃 설정 백업/복원 |
| R20 이하 (2015) | `_.-PLOT` 명령 | 영문 키워드 강제로 한/영 모두 동작 |
| ActiveX 실패 시 | `_.-PLOT` 자동 폴백 | Plot 객체 취득 실패 또는 PlotToFile 오류 시 |

**안전장치:**
- `*error*` 핸들러로 오류 시에도 레이아웃 설정 + 시스템 변수 복원 보장
- CMDECHO, BACKGROUNDPLOT, FILEDIA 자동 보존/복원
- 출력 파일 존재 여부 검증 + 성공/실패 카운트

## 빠른 시작

1. 저장소 클론:
   ```bash
   git clone https://github.com/notoow/autocad-dwf-exporter.git
   ```

2. AutoCAD에서:
   ```
   APPLOAD → export_dwf_main.lsp 로드
   EXPORT-DWF 명령 실행
   ```

**실행 흐름:**
```
EXPORT-DWF
 → 감지 방식 (샘플 클릭 / 레이어 입력)
 → 출력 형식 (DWF / PDF)
 → 저장 폴더 지정
 → 미리보기 (선택)
 → 내보내기 시작
```

## 파일 구조

```
autocad-dwf-exporter/
├── README.md
├── .gitignore
├── export_dwf_main.lsp     # 메인 스크립트 (EXPORT-DWF 명령)
└── export_dwf_ui.dcl       # DCL 다이얼로그 정의
```

## 전제조건

- AutoCAD 2015 이상
- `DWF6 ePlot.pc3` 또는 `DWG To PDF.pc3` 드라이버 설치
- UI 다이얼로그 사용 시, `export_dwf_ui.dcl` 파일을 **현재 작업 중인 도면(.dwg) 파일과 같은 폴더**에 배치하거나 AutoCAD 지원 파일 검색 경로에 추가해야 정상 동작합니다.

## 변경 이력

- **v5** — ActiveX 조기반환 버그 수정 (fallback-p), *error* 핸들러 순서 수정, -PLOT 프롬프트 정밀화, 한글 인코딩(ANSI) 수정
- **v4** — 단일 파일 통합, 버전별 플롯 엔진 자동 선택 (ActiveX + -PLOT 폴백), 레이아웃 설정 백업/복원
- **v3** — `_.-PLOT` 명령 전면 도입
- **v2** — 플롯 API 수정, 레이어 선택 추가
- **v1** — 초기 버전

---

<br><br>

<a name="english"></a>
# English

An AutoLISP script that automatically detects block references (INSERT) and polyline borders in AutoCAD drawings and batch exports each region into individual DWF or PDF files.

## Key Features

- **Select Output Format**: DWF (DWF6 ePlot) or PDF (DWG To PDF)
- **Dual Detection**: Detects both INSERT (Block References) and LWPOLYLINE simultaneously, automatically removing duplicates.
- **Sample Pick Mode**: Click a single border to automatically extract its layer and color properties.
- **ACI Color Filter**: Isolate detection to specific color entities.
- **Graphical UI (DCL)**: User-friendly dialog for folder browsing, preview counts, and filter adjustments.
- **Text Mode Fallback**: Can execute via command-line prompts if the DCL file is missing.
- **Smart Sorting**: Automatically sorts borders Top-to-Bottom, Left-to-Right based on average row height.

## Plot Engine

The script automatically selects the optimal plotting method based on the AutoCAD version.

| AutoCAD Version | Engine | Notes |
|-----------------|--------|-------|
| R21+ (2016~2025)| ActiveX PlotToFile | Uses `vlax-get-property doc 'Plot`, backs up/restores layout setups. |
| R20 & Below (2015)| `_.-PLOT` Command | Uses enforced English keywords to work on localized AutoCAD versions. |
| Fallback | `_.-PLOT` Fallback | Automatically falls back to the command line method if ActiveX fails. |

**Safeguards:**
- Robust `*error*` handler guarantees restoration of layout properties and system variables on failure.
- Auto preserves/restores CMDECHO, BACKGROUNDPLOT, and FILEDIA.
- Verifies output file existence + tracks success/failure counts.

## Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/notoow/autocad-dwf-exporter.git
   ```

2. Inside AutoCAD:
   ```
   Run APPLOAD → load export_dwf_main.lsp
   Type EXPORT-DWF in the command line
   ```

**Execution Flow:**
```
EXPORT-DWF
 → Select detection method (Sample Pick / Layer Input)
 → Select format (DWF / PDF)
 → Select output folder
 → Preview (Optional)
 → Start Batch Export
```

## File Structure

```
autocad-dwf-exporter/
├── README.md
├── .gitignore
├── export_dwf_main.lsp     # Core script (EXPORT-DWF command)
└── export_dwf_ui.dcl       # UI Dialog definition
```

## Prerequisites

- AutoCAD 2015 or newer
- `DWF6 ePlot.pc3` or `DWG To PDF.pc3` drivers must be installed
- For the UI to work, place the `export_dwf_ui.dcl` file **in the same folder as your target drawing (.dwg) file** or add it to the AutoCAD Support File Search Path.

## Changelog

- **v5** — Fixed ActiveX fallback bug, reordered *error* handler, refined -PLOT prompts, fixed ANSI encoding for Korean UI.
- **v4** — Unified into a single file, multi-engine plot support (ActiveX + -PLOT fallback), layout state preserving.
- **v3** — Complete rewrite using raw `_.-PLOT` command.
- **v2** — Plot API fixes, dynamic layer selection added.
- **v1** — Initial release.

---
## License
MIT License

**Keywords:** AutoCAD, DWF, PDF, batch export, AutoLISP, Visual LISP, batch plot, AutoCAD script, AutoCAD automation, CAD batch print, DWF converter, 일괄 내보내기, 도면 출력, 자동화, CAD 자동화, 도면 자동 출력
