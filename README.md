# narangd

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


# 참새 피하기 게임
1. 게임 기본 구성
농부 캐릭터를 좌우로 움직여 떨어지는 참새를 피하는 게임
터치 드래그로 캐릭터 이동 가능
참새와 충돌하면 게임 오버
2. 배경 요소
하늘과 논밭의 그라데이션 배경
황금빛 벼가 심어진 논밭 (랜덤하게 배치)
하늘에 떠다니는 구름 효과
3. 난이도 시스템
기본 속도: 280
레벨당 속도 증가: 45
최소 스폰 간격: 0.55초
레벨당 스폰 간격 감소: 0.045
10점마다 레벨업
4. UI 요소
메인 메뉴 화면
게임 중 상단에 현재 레벨과 점수 표시
게임 오버 화면에 최종 점수와 최고 기록 표시
5. 시각적 효과
참새의 날개짓 애니메이션
구름의 자연스러운 이동
레벨업 시 화면 중앙에 효과 표시
6. 데이터 관리
최고 점수 자동 저장
게임 재시작 시 이전 기록 유지
7. 캐릭터 디자인
밀짚모자를 쓴 농부 캐릭터
세밀한 표정과 의상 디테일
작업복과 모자 등 한국 농부의 특징을 반영
