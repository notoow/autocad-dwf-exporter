# AutoCAD DWF Exporter — 도면 일괄 DWF 내보내기 AutoLISP 스크립트

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![AutoCAD](https://img.shields.io/badge/AutoCAD-2018%2B-red.svg)](https://www.autodesk.com/products/autocad)
[![AutoLISP](https://img.shields.io/badge/AutoLISP-Visual%20LISP-green.svg)](#)

> **AutoCAD에서 여러 도면 영역을 자동 감지하고 각각을 개별 DWF 파일로 일괄 내보내는 자동화 스크립트**
>
> Batch export multiple drawing regions to individual DWF files from AutoCAD automatically.

## ✨ 주요 기능 | Key Features

- 🔍 **자동 테두리 감지** — FORM 레이어 블록참조 또는 색상 기반 폴리라인 자동 탐색
- 🎯 **샘플 선택 모드** — 테두리 하나를 클릭하면 동일 속성의 나머지를 자동 탐색
- 🎨 **색상 입력 모드** — ACI(1~255) 또는 RGB 색상값으로 직접 지정
- 🖥️ **GUI 다이얼로그** — DCL 기반 설정 UI (폴더 찾아보기, 미리보기, 필터 옵션)
- 📐 **스마트 정렬** — 위→아래, 좌→우 순서로 자동 도면 번호 부여
- 📦 **일괄 DWF 출력** — `도면1.dwf`, `도면2.dwf`, ... 형태로 개별 플롯
- ⚡ **텍스트 모드 폴백** — DCL 없이도 명령줄 모드로 실행 가능

## 📋 스크립트 목록 | Scripts

| 스크립트 | 명령어 | 감지 방식 | 설명 |
|----------|--------|-----------|------|
| `export_dwf_by_block.lsp` | `EXPORT-DWF` | FORM 레이어 블록참조 | 블록 기반 자동 감지 |
| `export_dwf_by_border.lsp` | `EXPORT-DWF-BORDERS` | 색상/샘플 기반 | UI 다이얼로그 지원 |

---

## 🚀 빠른 시작 | Quick Start

### 설치 | Installation

1. 이 저장소를 다운로드하거나 클론합니다:

```bash
git clone https://github.com/notoow/autocad-dwf-exporter.git
```

2. AutoCAD에서 LSP 파일을 로드합니다:

```
APPLOAD
```

3. 원하는 스크립트를 선택하여 로드합니다.

### 실행 | Usage

#### 방법 1: 블록 기반 내보내기 (FORM 레이어)

```
EXPORT-DWF
```

- FORM 레이어의 블록참조를 자동 탐색
- 못 찾으면 블록명 패턴 → 수동 선택 순으로 폴백

#### 방법 2: 테두리 감지 내보내기 (UI 버전)

```
EXPORT-DWF-BORDERS
```

- 다이얼로그 UI에서 감지 방식 선택
- 샘플 클릭 또는 색상값 직접 입력
- 미리보기로 감지 결과 확인 후 내보내기

---

## 📖 상세 사용법 | Detailed Usage

### export_dwf_by_block.lsp

FORM 레이어에 삽입된 블록참조(INSERT 객체)를 기반으로 도면 영역을 감지합니다.

**탐색 우선순위:**

| 순서 | 방법 | 조건 |
|------|------|------|
| 1 | 레이어 기반 | `FORM` 레이어의 `INSERT` 객체 |
| 2 | 블록명 기반 | 블록명 패턴 매칭 |
| 3 | 수동 선택 | 사용자가 직접 블록 선택 |

### export_dwf_by_border.lsp (UI 버전)

닫힌 폴리라인(LWPOLYLINE)을 기반으로 도면 테두리를 감지합니다.

**UI 다이얼로그 기능:**

| 기능 | 설명 |
|------|------|
| 🎯 샘플 선택 | 테두리 클릭 → 색상/레이어 자동 추출 |
| 🎨 색상 입력 | ACI 번호 또는 RGB 값 직접 지정 |
| 📂 폴더 찾아보기 | Windows 폴더 선택 다이얼로그 |
| 🔍 미리보기 | 내보내기 전 감지된 테두리 개수 확인 |
| ✅ 닫힌 폴리라인 필터 | 열린 폴리라인 제외 옵션 |
| 📏 최소 크기 필터 | 노이즈 제거용 크기 임계값 설정 |
| 🏷️ 레이어 매칭 | 같은 레이어의 객체만 매칭 |
| ✏️ 파일명 접두사 | 출력 파일명 커스터마이징 |

---

## ⚙️ 전제조건 | Requirements

- **AutoCAD 2018** 이상 (AutoLISP / Visual LISP 지원)
- **DWF6 ePlot.pc3** 드라이버 설치
- UI 사용 시 `export_dwf_border_ui.dcl` 파일을 LSP와 같은 폴더에 배치

## 📁 파일 구조 | File Structure

```
autocad-dwf-exporter/
├── README.md                      # 문서
├── .gitignore                     # Git 제외 설정
├── export_dwf_by_block.lsp        # 블록참조 기반 내보내기
├── export_dwf_by_border.lsp       # 테두리 감지 내보내기 (UI)
└── export_dwf_border_ui.dcl       # UI 다이얼로그 정의
```

## 💡 사용 예시 | Example Output

```
========================================
  DWF 일괄 내보내기 실행
========================================
  22개 테두리 감지됨.
  플롯 [1/22] → 도면1.dwf
  플롯 [2/22] → 도면2.dwf
  ...
  플롯 [22/22] → 도면22.dwf

✔ 완료! 22개 DWF 파일 생성됨
  저장 위치: C:\Users\...\도면폴더
```

## 🔧 커스터마이징 | Customization

### 플로터 변경

기본 플로터는 `DWF6 ePlot.pc3`입니다. UI에서 직접 변경하거나, LSP 파일 내의 플로터 설정을 수정할 수 있습니다.

### 파일명 형식 변경

UI 버전(`EXPORT-DWF-BORDERS`)에서는 파일명 접두사를 자유롭게 변경할 수 있습니다:
- `도면` → 도면1.dwf, 도면2.dwf, ...
- `Floor` → Floor1.dwf, Floor2.dwf, ...
- `Sheet` → Sheet1.dwf, Sheet2.dwf, ...

### 정렬 방식

도면 번호는 위→아래, 좌→우 순서로 자동 부여됩니다. 같은 행 여부는 블록 높이의 40%를 임계값으로 판단합니다.

---

## 📝 변경 이력 | Changelog

- **v1.1** — UI 기반 테두리 감지 스크립트 추가 (샘플 선택, 색상 입력, DCL 다이얼로그)
- **v1.0** — FORM 레이어 블록참조 기반 DWF 일괄 내보내기

## 🤝 기여 | Contributing

이슈 리포트나 PR을 환영합니다. 기능 요청이나 버그 리포트는 [Issues](https://github.com/notoow/autocad-dwf-exporter/issues)에 남겨주세요.

## 📄 라이선스 | License

MIT License — 자유롭게 사용, 수정, 배포할 수 있습니다.

---

## 🔑 Keywords

`AutoCAD` `DWF` `batch export` `AutoLISP` `Visual LISP` `일괄 내보내기` `도면 출력` `자동화` `CAD 자동화` `DWF6 ePlot` `batch plot` `AutoCAD script` `AutoCAD automation` `CAD batch print` `도면 DWF 변환` `DWF converter` `multiple drawings export` `AutoCAD 플롯` `도면 자동 출력` `CAD 도면 관리`
