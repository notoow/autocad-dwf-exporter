# AutoCAD DWF/PDF Exporter

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![AutoCAD](https://img.shields.io/badge/AutoCAD-2015~2025-red.svg)](https://www.autodesk.com/products/autocad)
[![AutoLISP](https://img.shields.io/badge/AutoLISP-Visual%20LISP-green.svg)](#)

AutoCAD 도면에서 블록참조(INSERT) 및 폴리라인(LWPOLYLINE) 테두리를 자동 감지하여 각각을 개별 DWF 또는 PDF 파일로 일괄 내보내는 AutoLISP 스크립트입니다.

Batch export multiple drawing regions to individual DWF/PDF files from AutoCAD with automatic border detection.

## 주요 기능

- DWF / PDF 출력 형식 선택 (DWF6 ePlot / DWG To PDF)
- INSERT(블록참조) + LWPOLYLINE(폴리라인) 동시 감지, 중복 자동 제거
- 샘플 클릭: 테두리 하나를 클릭하면 레이어/색상 자동 추출
- ACI 색상 필터: 특정 색상 객체만 선별 감지
- DCL 다이얼로그 UI (폴더 찾기, 미리보기, 필터 설정)
- DCL 없이도 텍스트 모드로 실행 가능
- 위→아래, 좌→우 자동 정렬 (평균 높이 기반 행 구분)

## 플롯 엔진

버전에 따라 자동으로 최적의 방식을 선택합니다.

| AutoCAD 버전 | 방식 | 비고 |
|-------------|------|------|
| R21+ (2016~2025) | ActiveX PlotToFile | `vlax-get-property doc 'Plot` 사용, 레이아웃 설정 백업/복원 |
| R20 이하 (2015) | `_.-PLOT` 명령 | 영문 키워드 강제로 한/영 모두 동작 |
| ActiveX 실패 시 | `_.-PLOT` 자동 폴백 | Plot 객체 취득 실패 또는 PlotToFile 오류 시 |

안전장치:
- `*error*` 핸들러로 오류 시에도 레이아웃 설정 + 시스템 변수 복원 보장
- CMDECHO, BACKGROUNDPLOT, FILEDIA 자동 보존/복원
- 출력 파일 존재 여부 검증 + 성공/실패 카운트

## 빠른 시작

```bash
git clone https://github.com/yourusername/autocad-dwf-exporter.git
```

AutoCAD에서:

```
APPLOAD → export_dwf_main.lsp 로드
EXPORT-DWF
```

실행 흐름:

```
EXPORT-DWF
 → 감지 방식 (샘플 클릭 / 레이어 입력)
 → 출력 형식 (DWF / PDF)
 → 저장 폴더
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

## 출력 예시

```
================================================
  DWF/PDF 일괄 내보내기  v5
  AutoCAD R25
================================================
  22개 감지. 정렬 중...
  [1/22] 도면1.dwf OK
  [2/22] 도면2.dwf OK
  ...
  [22/22] 도면22.dwf OK

================================================
  성공: 22개
  위치: C:\Users\...\도면폴더
================================================
```

## 전제조건

- AutoCAD 2015 이상
- DWF6 ePlot.pc3 또는 DWG To PDF.pc3 드라이버 설치
- UI 사용 시 `export_dwf_ui.dcl`을 LSP와 같은 폴더에 배치

## 변경 이력

- **v5** — ActiveX 조기반환 버그 수정 (fallback-p), *error* 핸들러 순서 수정, -PLOT 프롬프트 정밀화
- **v4** — 단일 파일 통합, 버전별 플롯 엔진 자동 선택 (ActiveX + -PLOT 폴백), 레이아웃 설정 백업/복원
- **v3** — `_.-PLOT` 명령 전면 도입
- **v2** — 플롯 API 수정, 레이어 선택 추가
- **v1** — 초기 버전

## 라이선스

MIT License

---

**Keywords:** AutoCAD, DWF, PDF, batch export, AutoLISP, Visual LISP, batch plot, AutoCAD script, AutoCAD automation, CAD batch print, DWF converter, 일괄 내보내기, 도면 출력, 자동화, CAD 자동화, 도면 자동 출력
