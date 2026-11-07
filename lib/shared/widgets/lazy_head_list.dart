import 'package:flutter/material.dart';

/// A scrolling list made of a short, fixed [head] (filters, summaries, empty
/// states) followed by [rowCount] rows that are built lazily. Looks like a
/// plain `ListView(children: [...head, ...rows])` but only builds the rows
/// that are on screen.
class LazyHeadList extends StatelessWidget {
  const LazyHeadList({
    super.key,
    required this.head,
    required this.rowCount,
    required this.rowBuilder,
    this.padding,
    this.controller,
  });

  final List<Widget> head;
  final int rowCount;
  final IndexedWidgetBuilder rowBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: head.length + rowCount,
      itemBuilder: (context, i) =>
          i < head.length ? head[i] : rowBuilder(context, i - head.length),
    );
  }
}
