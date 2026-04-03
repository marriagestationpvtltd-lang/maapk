import 'package:flutter/material.dart';

class TypingDropdown<T> extends StatefulWidget {
  final bool showError;

  final List<T> items;
  final String Function(T) itemLabel;
  final T? selectedItem;
  final void Function(T?) onChanged;
  final String hint;
  final String title;

  const TypingDropdown({
    Key? key,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.selectedItem,
    this.hint = "Select",
    required this.title,
    required this.showError,
  }) : super(key: key);


  @override
  State<TypingDropdown<T>> createState() => _TypingDropdownState<T>();
}

class _TypingDropdownState<T> extends State<TypingDropdown<T>> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(
      text: widget.selectedItem != null
          ? widget.itemLabel(widget.selectedItem!)
          : '',
    );
  }

  void _openBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.65, // 👈 HALF SCREEN (65%)
          child: _BottomSheetContent<T>(
            items: widget.items,
            itemLabel: widget.itemLabel,
            selectedItem: widget.selectedItem,
            title: widget.title,
            onSelected: (item) {
              controller.text = widget.itemLabel(item);
              widget.onChanged(item);
              Navigator.pop(context);
            },
            onClear: () {
              controller.clear();
              widget.onChanged(null);
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        widget.showError && widget.selectedItem == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            border:
            Border.all(
              color: hasError
                  ? Colors.red
                  : widget.selectedItem == null
                  ? Colors.black
                  : Colors.green,
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(15),
          ),
          child:
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: _openBottomSheet,
            child: IgnorePointer(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  suffixIcon:
                  const Icon(Icons.keyboard_arrow_down),
                ),
              ),
            ),
          ),
        ),

        /// ERROR TEXT
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 8),
            child: Text(
              "Please select ${widget.title}",
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _BottomSheetContent<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) itemLabel;
  final T? selectedItem;
  final String title;
  final void Function(T) onSelected;
  final VoidCallback onClear;

  const _BottomSheetContent({
    required this.items,
    required this.itemLabel,
    required this.onSelected,
    required this.onClear,
    this.selectedItem,
    required this.title,
  });

  @override
  State<_BottomSheetContent<T>> createState() =>
      _BottomSheetContentState<T>();
}

class _BottomSheetContentState<T>
    extends State<_BottomSheetContent<T>> {
  late List<T> filteredItems;
  final TextEditingController searchController =
  TextEditingController();

  @override
  void initState() {
    super.initState();
    filteredItems = widget.items;
    searchController.addListener(_filter);
  }

  void _filter() {
    final q = searchController.text.toLowerCase();
    setState(() {
      filteredItems = widget.items
          .where((e) =>
          widget.itemLabel(e).toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// TITLE
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE64B37),
              ),
            ),

            const SizedBox(height: 12),

            /// SELECTED CHIP
            if (widget.selectedItem != null)
              Wrap(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE64B37)
                          .withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE64B37),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget
                              .itemLabel(widget.selectedItem!),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: widget.onClear,
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Color(0xFFE64B37),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            /// SEARCH
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding:
                const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
              ),
            ),

            const SizedBox(height: 16),

            /// LIST
            Expanded(
              child: ListView.builder(
                itemCount: filteredItems.length,
                itemBuilder: (_, index) {
                  final item = filteredItems[index];
                  return ListTile(
                    title:
                    Text(widget.itemLabel(item)),
                    onTap: () =>
                        widget.onSelected(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
