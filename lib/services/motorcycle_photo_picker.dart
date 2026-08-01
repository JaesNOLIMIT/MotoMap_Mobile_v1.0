import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/motomap_colors.dart';

class MotorcyclePhotoPicker {
  MotorcyclePhotoPicker._();

  static Future<XFile?> pickAndCrop(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 92,
      requestFullMetadata: false,
    );
    if (picked == null || !context.mounted) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      maxWidth: 1600,
      maxHeight: 900,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 86,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Fit motorcycle photo',
          toolbarColor: MotoMapColors.surface,
          toolbarWidgetColor: MotoMapColors.onSurface,
          backgroundColor: MotoMapColors.surface,
          activeControlsWidgetColor: MotoMapColors.primary,
          cropFrameColor: MotoMapColors.primary,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          aspectRatioPresets: const [CropAspectRatioPreset.ratio16x9],
        ),
        IOSUiSettings(
          title: 'Fit motorcycle photo',
          doneButtonTitle: 'Use photo',
          cancelButtonTitle: 'Cancel',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          aspectRatioPresets: const [CropAspectRatioPreset.ratio16x9],
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          initialAspectRatio: 16 / 9,
          movable: true,
          zoomable: true,
          cropBoxResizable: false,
          barrierColor: Colors.black.withValues(alpha: 0.82),
        ),
      ],
    );
    if (cropped == null) return null;
    return XFile(cropped.path, mimeType: 'image/jpeg');
  }
}
