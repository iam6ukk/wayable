# kakao_map_sdk(com.kakao.maps.open:android)는 네이티브(JNI) 코드에서
# com.kakao.vectormap.internal.* 클래스를 리플렉션으로 참조하는데,
# R8은 그 참조를 못 보고 안 쓰는 클래스로 판단해 지워버린다(MapViewHolder가
# 통째로 사라져 RenderViewOptions.listener 필드 조회 시 ClassNotFoundException
# -> SIGABRT). 이 SDK가 자체 consumer proguard 규칙을 안 갖고 있어 직접
# keep 규칙을 추가해야 한다.
-keep class com.kakao.vectormap.** { *; }
-keep interface com.kakao.vectormap.** { *; }
-keep class com.kakao.maps.** { *; }
-dontwarn com.kakao.vectormap.**
-dontwarn com.kakao.maps.**
