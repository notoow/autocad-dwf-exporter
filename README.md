# AutoCAD DWF/PDF Exporter

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![AutoCAD](https://img.shields.io/badge/AutoCAD-2018%2B-red.svg)](https://www.autodesk.com/products/autocad)
[![AutoLISP](https://img.shields.io/badge/AutoLISP-Visual%20LISP-green.svg)](#)

AutoCAD에서 여러 도면 영역을 자동 감지하고 각각을 개별 DWF 또는 PDF 파일로 일괄 내보내는 AutoLISP 스크립트입니다.

Batch export multiple drawing regions to individual DWF/PDF files from AutoCAD automatically.

## 주요 기능

- DWF / PDF 출력 형식 선택
- 블록참조(INSERT) 및 폴리라인(LWPOLYLINE) 자동 감지
- 샘플 선택: 테두리 하나를 클릭하면 동일 속성 자동 탐색
- 색상 입력: ACI(1~255) 또는 RGB 값으로 직접 지정
- DCL 기반 GUI 다이얼로그 (폴더 찾기, 미리보기, 필터)
- 위→아래, 좌→우 순서 자동 정렬
- `_.-PLOT` 명령 기반으로 버전 호환성 확보
- 레이아웃 페이지 설정 미변경, 시스템 변수 자동 복원

## 스크립트 목록

| 스크립트 | 명령어 | 감지 방식 | 출력 |
|----------|--------|-----------|------|
| `export_dwf_by_block.lsp` | `EXPORT-DWF` | 레이어별 블록참조(INSERT) | DWF / PDF |
| `export_dwf_by_border.lsp` | `EXPORT-DWF-BORDERS` | 색상/샘플 기반 (INSERT + 폴리라인) | DWF / PDF |

---

## 빠른 시작

### 설치

```bash
git clone https://github.com/notoow/autocad-dwf-exporter.git
```

AutoCAD에서:

```
APPLOAD → .lsp 파일 선택하여 로드
```

### 실행

#### 방법 1: 블록 기반 (EXPORT-DWF)

```
EXPORT-DWF
→ 레이어 선택 (클릭 / 목록 / 직접입력)
→ 출력 형식 (DWF / PDF)
→ 저장 폴더 지정
→ 자동 내보내기
```

#### 방법 2: 테두리 감지 UI (EXPORT-DWF-BORDERS)

```
EXPORT-DWF-BORDERS
→ 다이얼로그에서 설정
→ 미리보기로 감지 결과 확인
→ 내보내기 시작
```

---

## 상세 사용법

### export_dwf_by_block.lsp

특정 레이어에 삽입된 블록참조(INSERT)를 기반으로 도면 영역을 감지합니다.

**레이어 선택 방법:**

| 방법 | 설명 |
|------|------|
| 블록 클릭 | 테두리 블록 하나를 클릭하면 레이어 자동 감지 |
| 목록 선택 | 도면의 전체 레이어 목록에서 번호로 선택 |
| 직접 입력 | 레이어명을 직접 입력 |

### export_dwf_by_border.lsp (UI 버전)

INSERT(블록참조)와 LWPOLYLINE(폴리라인)을 모두 감지합니다.

**UI 다이얼로그 기능:**

| 기능 | 설명 |
|------|------|
| 샘플 선택 | 테두리 클릭 → 색상/레이어/엔티티타입 자동 감지 |
| 색상 입력 | ACI 번호 또는 RGB 값 직접 지정 |
| 출력 형식 | DWF / PDF 라디오 버튼 선택 |
| 폴더 찾기 | Windows 폴더 선택 다이얼로그 |
| 미리보기 | 내보내기 전 감지된 테두리 개수 확인 |
| 필터 옵션 | 닫힌 폴리라인만, 같은 레이어만, 최소 크기 |
| 커스터마이징 | 파일명 접두사, 플로터 이름 변경 |
| 텍스트 모드 | DCL 파일 없어도 명령줄 모드로 실행 가능 |

---

## 플롯 엔진

`_.-PLOT` 명령을 직접 실행합니다. COM API (`vla-PlotToFile`) 대신 사용하여 버전 호환성을 확보했습니다.

| 항목 | 설명 |
|------|------|
| 버전 호환 | `_` 접두사로 한/영 AutoCAD 모두 동작 |
| 페이지 설정 | 레이아웃 페이지 설정을 변경하지 않음 |
| 시스템 변수 | CMDECHO, BACKGROUNDPLOT, FILEDIA 자동 보존/복원 |
| 에러 처리 | `*error*` 핸들러로 오류 시에도 시스템 변수 복원 보장 |
| 결과 확인 | 출력 파일 존재 여부 검증 + 성공/실패 카운트 |

**지원 플로터:**

| 형식 | 플로터 | 확장자 |
|------|--------|--------|
| DWF | DWF6 ePlot.pc3 | .dwf |
| PDF | DWG To PDF.pc3 | .pdf |

---

## 전제조건

- AutoCAD 2018 이상 (AutoLISP / Visual LISP 지원)
- DWF6 ePlot.pc3 또는 DWG To PDF.pc3 드라이버 설치
- UI 사용 시 `export_dwf_border_ui.dcl` 파일을 LSP와 같은 폴더에 배치

## 파일 구조

```
autocad-dwf-exporter/
├── README.md
├── .gitignore
├── export_dwf_by_block.lsp        # 블록참조 기반 (EXPORT-DWF)
├── export_dwf_by_border.lsp       # 테두리 감지 UI (EXPORT-DWF-BORDERS)
└── export_dwf_border_ui.dcl       # DCL 다이얼로그 정의
```

## 출력 예시

```
============================================
  DWF/PDF 일괄 내보내기 - 블록참조 기준
============================================
  레이어: FORM
  22개 감지.
  [1/22] 도면1.dwf ✔
  [2/22] 도면2.dwf ✔
  ...
  [22/22] 도면22.dwf ✔

========================================
  ✔ 성공: 22개
  위치: C:\Users\...\도면폴더
========================================
```

## 변경 이력

- **v3** — `_.-PLOT` 명령 방식으로 전면 교체, PDF 지원, INSERT+LWPOLYLINE 감지, 에러핸들러 개선
- **v2** — 플롯 API 수정 (vla-SetWindowToPlot), 레이어 선택 추가
- **v1** — 초기 버전

## 기여

이슈 리포트나 PR을 환영합니다. [Issues](https://github.com/notoow/autocad-dwf-exporter/issues)

## 라이선스

MIT License

---

**Keywords:** AutoCAD, DWF, PDF, batch export, AutoLISP, Visual LISP, 일괄 내보내기, 도면 출력, 자동화, CAD 자동화, batch plot, AutoCAD script, AutoCAD automation, 도면 DWF 변환, PDF 변환, AutoCAD 플롯, 도면 자동 출력
