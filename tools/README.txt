블러드본 Enhanced + Vanilla Plus 한글 번역 모드 제작 도구
================================================================

결과물: mods\Korean Translation - Enhanced + Vanilla Plus
  - dvdroot_ps4\msg\engus, enggb   : 한글 메시지 (item / menu .msgbnd.dcx)
  - dvdroot_ps4\menu\engus, enggb  : 한글 폰트 (Font- 03173 normal hangul, eng embed 에서 복사)

필요한 것: Windows PowerShell 5.1 (기본 내장). 원본 게임 파일
  C:\bbport-windows\GAME\CUSA03173-patch\dvdroot_ps4\msg (engus, korkr) 을 기준으로 씀.


모드가 업데이트됐을 때 다시 만드는 순서
----------------------------------------------------------------
PowerShell 에서 이 폴더의 스크립트를 순서대로 실행:

1) build.ps1
   원본 한글 + Enhanced / Vanilla Plus 메시지를 병합해서
   mods\Korean msg - Enhanced (+ Vanilla Plus) 폴더를 다시 만든다.
   (새 항목은 영어로, Enhanced 가 바꾼 항목도 영어로, V+ 의 철자 수정은 한글 유지)

2) prep.ps1
   병합 결과에서 영어로 남은 항목을 모아 units.json 을 만든다.
   원본 게임에 똑같은 영어 문장이 있으면 공식 한글 번역을 자동으로 쓴다.

3) batch.ps1
   번역 단위(templates.json)를 만들고, translations.json 에 아직 없는
   "새 문장"만 batch_0.json, batch_1.json ... 으로 뽑는다.
   glossary.tsv(공식 용어집)도 다시 만든다.
   -> "new templates to translate: 0" 이면 4) 는 건너뛰면 된다.

4) batch_N.json 을 번역해서 같은 폴더에 batch_N.out.json 으로 저장
   형식: { "T12": "한글 번역", ... }  (key 는 batch 파일의 key)
   - {n0}, {n1} 같은 숫자 자리표시와 <?...?> 태그는 그대로 둘 것
   - ref_ko 가 있으면 공식 번역을 최대한 재사용
   - 고유명사는 glossary.tsv 의 공식 용어 사용
   (Claude 에게 "batch_N.json 번역해줘" 라고 맡기면 됨)

5) apply.ps1
   translations.json + 새 batch_N.out.json 을 합쳐 번역 모드 폴더를 다시 만들고,
   새 번역은 translations.json 에 자동으로 추가된다.
   마지막 줄 "leftover English" 가 3 이면 정상 (-!, 빈칸, null 자리표시).


파일 설명
----------------------------------------------------------------
Msg.cs / MsgWrite.cs  : msgbnd.dcx (DCX + BND4 + FMG v2) 읽기/쓰기
Tr.cs                 : 영어 문장 정규화/유사도 (원본 번역 재사용용)
translations.json     : 번역 메모리 (영어 템플릿 -> 한글), 949개
glossary.tsv          : 원본 게임 영어->한글 공식 용어집
units.json / templates.json : 중간 결과물 (스크립트가 다시 만듦)

apply.ps1 의 Fix-Term 에서 용어를 일괄 교정한다
(장치 무기, 계몽, 리그의 맹약, 유령 변형이다, 점화의 의식 등).
용어를 바꾸고 싶으면 거기에 한 줄 추가하고 apply.ps1 만 다시 실행하면 된다.

주의: 경로는 C:\bbport-windows 기준으로 스크립트에 적혀 있다.
      모드 폴더 이름(bb_enhanced_0.11.5-fix3, Vanilla_Plus_v1.20)이 바뀌면
      build.ps1 상단의 $E / $V 경로를 고칠 것.
