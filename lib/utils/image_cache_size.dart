/// Image.network의 cacheWidth/cacheHeight에 넘길 물리 픽셀 값을 계산한다.
int cacheDimension(double logicalSize, double devicePixelRatio) =>
    (logicalSize * devicePixelRatio).round();
