import 'dart:io';
import 'package:image/image.dart';

void main() {
  final srcFile = File(r'C:\Users\richa\.gemini\antigravity-ide\brain\2ebca502-90cd-4a15-bd0f-2709022904ac\.user_uploaded\media_1792476212902.jpg');
  final bytes = srcFile.readAsBytesSync();
  final src = decodeImage(bytes)!;

  print('Source image: ${src.width}x${src.height}');

  // 1. Identify background pixels connected to the boundary
  final isBg = List.generate(src.height, (_) => List.filled(src.width, false));
  final queue = <List<int>>[];

  bool isNearWhite(int x, int y) {
    final p = src.getPixel(x, y);
    return p.r > 220 && p.g > 220 && p.b > 220;
  }

  // Seed boundary
  for (int x = 0; x < src.width; x++) {
    if (isNearWhite(x, 0)) { isBg[0][x] = true; queue.add([x, 0]); }
    if (isNearWhite(x, src.height - 1)) { isBg[src.height - 1][x] = true; queue.add([x, src.height - 1]); }
  }
  for (int y = 0; y < src.height; y++) {
    if (isNearWhite(0, y)) { isBg[y][0] = true; queue.add([0, y]); }
    if (isNearWhite(src.width - 1, y)) { isBg[y][src.width - 1] = true; queue.add([src.width - 1, y]); }
  }

  while (queue.isNotEmpty) {
    final pt = queue.removeLast();
    final x = pt[0];
    final y = pt[1];

    for (final offset in const [[-1, 0], [1, 0], [0, -1], [0, 1]]) {
      final nx = x + offset[0];
      final ny = y + offset[1];
      if (nx >= 0 && nx < src.width && ny >= 0 && ny < src.height) {
        if (!isBg[ny][nx] && isNearWhite(nx, ny)) {
          isBg[ny][nx] = true;
          queue.add([nx, ny]);
        }
      }
    }
  }

  // Also include whitespace in lower section (between/inside DREAM TEAM letters)
  for (int y = 50; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      if (isNearWhite(x, y)) {
        isBg[y][x] = true;
      }
    }
  }

  // Cleaned version for white background
  final cleaned = Image.from(src);
  for (int y = 0; y < cleaned.height; y++) {
    for (int x = 0; x < cleaned.width; x++) {
      if (isBg[y][x]) {
        cleaned.setPixelRgba(x, y, 255, 255, 255, 255);
      }
    }
  }

  // Transparent background version
  final transparentLogo = Image(width: src.width, height: src.height, numChannels: 4);
  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      if (isBg[y][x]) {
        transparentLogo.setPixelRgba(x, y, 255, 255, 255, 0);
      } else {
        transparentLogo.setPixelRgba(x, y, p.r, p.g, p.b, 255);
      }
    }
  }

  // Content bounding box: x: 0 to 251, y: 4 to 95 -> width: 252, height: 92
  final croppedClean = copyCrop(cleaned, x: 0, y: 4, width: 252, height: 92);
  final croppedTrans = copyCrop(transparentLogo, x: 0, y: 4, width: 252, height: 92);

  // 2. Generate 1024x1024 App Icon (Solid White Background for iOS/Web/Legacy Android)
  final targetW = 760;
  final targetH = (targetW * 92 / 252).round();
  final resizedLogo = copyResize(croppedClean, width: targetW, height: targetH, interpolation: Interpolation.cubic);

  final appIcon = Image(width: 1024, height: 1024, numChannels: 4);
  fill(appIcon, color: ColorRgba8(255, 255, 255, 255));

  final startX = (1024 - targetW) ~/ 2;
  final startY = (1024 - targetH) ~/ 2;
  compositeImage(appIcon, resizedLogo, dstX: startX, dstY: startY);

  final appIconPath = 'assets/images/app_icon.png';
  File(appIconPath).writeAsBytesSync(encodePng(appIcon));
  print('Saved $appIconPath (760x$targetH centered on 1024x1024 white canvas)');

  // 3. Generate 1024x1024 Adaptive Foreground (Transparent Background for Android Adaptive Icons)
  // Because Android applies an inset of 16% (leaving 68% effective scale),
  // sizing to 850px width yields an effective visible size of 578px, perfectly fitting the circular safe zone.
  final adaptW = 850;
  final adaptH = (adaptW * 92 / 252).round();
  final resizedTransLogo = copyResize(croppedTrans, width: adaptW, height: adaptH, interpolation: Interpolation.cubic);

  final adaptiveFg = Image(width: 1024, height: 1024, numChannels: 4);
  fill(adaptiveFg, color: ColorRgba8(255, 255, 255, 0));

  final adaptStartX = (1024 - adaptW) ~/ 2;
  final adaptStartY = (1024 - adaptH) ~/ 2;
  compositeImage(adaptiveFg, resizedTransLogo, dstX: adaptStartX, dstY: adaptStartY);

  final adaptiveFgPath = 'assets/images/app_icon_foreground.png';
  File(adaptiveFgPath).writeAsBytesSync(encodePng(adaptiveFg));
  print('Saved $adaptiveFgPath (850x$adaptH centered on 1024x1024 transparent canvas)');
}
