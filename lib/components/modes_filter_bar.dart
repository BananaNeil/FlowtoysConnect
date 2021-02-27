import 'package:app/helpers/animated_clip_rect.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

class ModesFilterBar extends StatefulWidget {
  ModesFilterBar({
    Key key,
    this.filterController,
  }) : super(key: key);

  BehaviorSubject<Map<String, dynamic>> filterController;

  @override
  _ModesFilterBar createState() => _ModesFilterBar();

}


class _ModesFilterBar extends State<ModesFilterBar> {
  _ModesFilterBar();

  List<String> activeFilters = [];
  bool filtersExpanded = false;
  List<String> keywordFilter;

  List<dynamic> filters = [
    {
      'title': 'Motion Reactive',
      'attr': 'motionReactive',
    }, {
      'title': 'Stall Reactive',
      'attr': 'stallReactive',
    }, {
      'title': 'Bump Reactive',
      'attr': 'bumpReactive',
    }, {
      'title': 'Spin Reactive',
      'attr': 'spinReactive',
    }
  ];

  @override
  initState() {
    super.initState();
    updateFilterStream();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 10, right: 20, top: 8, bottom: 8),
      decoration: BoxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(left: 0),
            child: GestureDetector(
              onTap: () {
                setState(() => filtersExpanded = !filtersExpanded);
              },
              child: Row(
                children: [
                  Text("SHOW FILTERS",
                    textAlign: TextAlign.left,
                    style: TextStyle(fontSize: 14)
                  ),
                  Container(
                    child: filtersExpanded ? Icon(Icons.expand_more) : Icon(Icons.chevron_right),
                  )
                ]
              )
            ),
          ),
          AnimatedClipRect(
            child: _Filters,
            open: filtersExpanded,
            curve: Curves.easeInOut,
            verticalAnimation: true,
            horizontalAnimation: false,
            alignment: Alignment.topCenter,
            duration: Duration(milliseconds: 201),
          ),
        ]
      ),
    );
  }

  List<String> parseKeywords(keywords) {
    List<String> words = keywords.toLowerCase().replaceAll(RegExp(r'[^a-z]'), ' ').split(' ');
    return words.where((word) => word.length > 1).toList();
  }

  Widget get _Filters {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            onChanged: (keywords) {
              keywordFilter = parseKeywords(keywords);
              updateFilterStream();
            },
            decoration: InputDecoration(
              hintText: 'Search modes'
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(left: 15, top: 10),
          child: Wrap(
            spacing: 20,
            children: filters.map((filter) {
              return _FilterWidget(title: filter['title'], attr: filter['attr']);
            }).toList(),
          )
        )
      ]
    );
  }

  Widget _FilterWidget({title, attr}) {
    return Container(
      height: 35,
      child: _Checkbox(
        title: Text(title),
        value: activeFilters.contains(attr),
        onChanged: (newValue) {
          setState(() {
            if (activeFilters.contains(attr))
              activeFilters.remove(attr);
            else activeFilters.add(attr);
            updateFilterStream();
          });
        },
      )
    );
  }

  void updateFilterStream() {
    widget.filterController.sink.add({
      'activeFilters': activeFilters,
      'keywordFilter': keywordFilter,
    });
  }

  Widget _Checkbox({title, value, onChanged, padding}) {
		return InkWell(
      onTap: () {
        onChanged(!value);
      },
      child: Padding(
        padding: padding ?? EdgeInsets.all(0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Checkbox(
              value: value,
              onChanged: (bool newValue) {
                onChanged(newValue);
              },
            ),
            Container(child: title),
          ],
        ),
      ),
		);
	}
}
