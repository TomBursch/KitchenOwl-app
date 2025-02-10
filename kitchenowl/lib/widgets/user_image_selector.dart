import 'package:flutter/material.dart';
import 'package:kitchenowl/helpers/named_bytearray.dart';
import 'package:kitchenowl/kitchenowl.dart';

class UserImageSelector extends StatelessWidget {
  final NamedByteArray? image;
  final String? originalImage;
  final void Function(NamedByteArray) setImage;
  final String? tooltip;
  final String? name;

  const UserImageSelector({
    super.key,
    this.image,
    this.originalImage,
    required this.setImage,
    this.tooltip,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundImage: hasDominantImage() ? getDominantImage(context)! : null,
      radius: 45,
      child: IconButton(
        icon: hasDominantImage()
            ? const Icon(Icons.edit)
            : const Icon(Icons.add_photo_alternate_rounded),
        tooltip: tooltip ?? AppLocalizations.of(context)!.imageSelect,
        color: hasDominantImage()
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.onSecondary,
        onPressed: () async {
          NamedByteArray? file = await selectFile(
            context: context,
            title: tooltip ?? AppLocalizations.of(context)!.imageSelect,
            deleteOption: hasDominantImage(),
          );
          if (file != null) {
            setImage(file);
          }
        },
      ),
    );
  }

  bool hasDominantImage() {
    if (image != null && image!.isNotEmpty) {
      return true;
    } else if (image == null && (originalImage?.isNotEmpty ?? false)) {
      return true;
    } else {
      return false;
    }
  }

  ImageProvider<Object>? getDominantImage(BuildContext context) {
    if (image != null && image!.isNotEmpty) {
      return MemoryImage(image!.bytes);
    } else if (originalImage?.isNotEmpty ?? false) {
      return getImageProvider(
        context,
        originalImage!,
        maxWidth: MediaQuery.of(context).size.width.toInt(),
      );
    } else {
      return null;
    }
  }
}
