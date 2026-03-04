import 'package:flutter/material.dart';

class CustomSearchField<T extends Object> extends StatefulWidget {
  final List<T> items;
  final String label;
  final String hint;
  final String Function(T) displayStringForOption;
  final Widget Function(BuildContext, T) listItemBuilder;
  final Function(T) onSelected;
  final Widget? prefixIcon;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  const CustomSearchField({
    super.key,
    required this.items,
    required this.label,
    required this.hint,
    required this.displayStringForOption,
    required this.listItemBuilder,
    required this.onSelected,
    this.prefixIcon,
    this.controller,
    this.focusNode,
  });

  @override
  State<CustomSearchField<T>> createState() => _CustomSearchFieldState<T>();
}

class _CustomSearchFieldState<T extends Object>
    extends State<CustomSearchField<T>> {
  late FocusNode _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void didUpdateWidget(covariant CustomSearchField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _internalFocusNode.dispose();
      }
      _internalFocusNode = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _internalFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<T>(
          textEditingController: widget.controller,
          focusNode: _internalFocusNode,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable.empty();
            }
            return widget.items.where((T option) {
              return widget
                  .displayStringForOption(option)
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase());
            });
          },
          displayStringForOption: widget.displayStringForOption,
          onSelected: widget.onSelected,
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController textEditingController,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return TextField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText: widget.hint,
                    prefixIcon: widget.prefixIcon,
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onTap: () {
                    // RawAutocomplete handles focus
                  },
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<T> onSelected,
                Iterable<T> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      width: constraints.maxWidth,
                      color: Colors.white,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) {
                          final T option = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: widget.listItemBuilder(context, option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }
}
