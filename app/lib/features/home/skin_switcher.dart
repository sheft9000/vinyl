import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ios.dart';
import '../../core/skin.dart';

/// Selettore temporaneo fra le due direzioni estetiche in prova.
/// Sparisce insieme a [Skin] quando avrai scelto.
class SkinSwitcher extends ConsumerWidget {
  const SkinSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(IOS.margin, 4, IOS.margin, 10),
      child: SizedBox(
        width: double.infinity,
        child: CupertinoSlidingSegmentedControl<Skin>(
          groupValue: skin,
          backgroundColor: IOS.surface,
          thumbColor: IOS.surfaceHigher,
          padding: const EdgeInsets.all(3),
          onValueChanged: (value) {
            if (value != null) ref.read(skinProvider.notifier).set(value);
          },
          children: {
            for (final option in Skin.values)
              option: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  option.label,
                  style: IOSText.footnote.copyWith(
                    color: option == skin ? IOS.label : IOS.labelSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          },
        ),
      ),
    );
  }
}
