// Copyright (c) 2018, the Zefyr project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:notus/notus.dart';

import 'editor.dart';
import 'theme.dart';
import 'toolbar.dart';

/// A button used in [ZefyrToolbar].
///
/// Create an instance of this widget with [ZefyrButton.icon] or
/// [ZefyrButton.text] constructors.
///
/// Toolbar buttons are normally created by a [ZefyrToolbarDelegate].
class ZefyrButton extends StatelessWidget {
  /// Creates a toolbar button with an icon.
  ZefyrButton.icon({
    @required this.action,
    @required IconData icon,
    double iconSize,
    this.onPressed,
  })  : assert(action != null),
        assert(icon != null),
        _icon = icon,
        _iconSize = iconSize,
        _text = null,
        _textStyle = null,
        super();

  /// Creates a toolbar button containing text.
  ///
  /// Note that [ZefyrButton] has fixed width and does not expand to accommodate
  /// long texts.
  ZefyrButton.text({
    @required this.action,
    @required String text,
    TextStyle style,
    this.onPressed,
  })  : assert(action != null),
        assert(text != null),
        _icon = null,
        _iconSize = null,
        _text = text,
        _textStyle = style,
        super();

  /// Toolbar action associated with this button.
  final ZefyrToolbarAction action;
  final IconData _icon;
  final double _iconSize;
  final String _text;
  final TextStyle _textStyle;

  /// Callback to trigger when this button is tapped.
  final VoidCallback onPressed;

  bool get isAttributeAction {
    return kZefyrToolbarAttributeActions.keys.contains(action);
  }

  @override
  Widget build(BuildContext context) {
    final editor = ZefyrEditor.of(context);
    final toolbar = ZefyrToolbar.of(context);
    final toolbarTheme = ZefyrTheme.of(context).toolbarTheme;
    final pressedHandler = _getPressedHandler(editor, toolbar);
    final iconColor = (pressedHandler == null)
        ? toolbarTheme.disabledIconColor
        : toolbarTheme.iconColor;
    if (_icon != null) {
      return RawZefyrButton.icon(
        action: action,
        icon: _icon,
        size: _iconSize,
        iconColor: iconColor,
        color: _getColor(editor, toolbarTheme),
        onPressed: _getPressedHandler(editor, toolbar),
      );
    } else {
      assert(_text != null);
      var style = _textStyle ?? new TextStyle();
      style = style.copyWith(color: iconColor);
      return RawZefyrButton(
        action: action,
        child: new Text(_text, style: style),
        color: _getColor(editor, toolbarTheme),
        onPressed: _getPressedHandler(editor, toolbar),
      );
    }
  }

  Color _getColor(ZefyrEditorScope editor, ZefyrToolbarTheme theme) {
    if (isAttributeAction) {
      final attribute = kZefyrToolbarAttributeActions[action];
      final isToggled = (attribute is NotusAttribute)
          ? editor.selectionStyle.containsSame(attribute)
          : editor.selectionStyle.contains(attribute);
      return isToggled ? theme.toggleColor : null;
    }
    return null;
  }

  VoidCallback _getPressedHandler(
      ZefyrEditorScope editor, ZefyrToolbarState toolbar) {
    if (onPressed != null) {
      return onPressed;
    } else if (isAttributeAction) {
      final attribute = kZefyrToolbarAttributeActions[action];
      if (attribute is NotusAttribute) {
        return () => _toggleAttribute(attribute, editor);
      }
    } else if (action == ZefyrToolbarAction.close) {
      return () => toolbar.closeOverlay();
    } else if (action == ZefyrToolbarAction.hideKeyboard) {
      return () => editor.hideKeyboard();
    }

    return null;
  }

  void _toggleAttribute(NotusAttribute attribute, ZefyrEditorScope editor) {
    final isToggled = editor.selectionStyle.containsSame(attribute);
    if (isToggled) {
      editor.formatSelection(attribute.unset);
    } else {
      editor.formatSelection(attribute);
    }
  }
}

/// Raw button widget used by [ZefyrToolbar].
///
/// See also:
///
///   * [ZefyrButton], which wraps this widget and implements most of the
///     action-specific logic.
class RawZefyrButton extends StatelessWidget {
  const RawZefyrButton({
    Key key,
    @required this.action,
    @required this.child,
    @required this.color,
    @required this.onPressed,
  }) : super(key: key);

  /// Creates a [RawZefyrButton] containing an icon.
  RawZefyrButton.icon({
    @required this.action,
    @required IconData icon,
    double size,
    Color iconColor,
    @required this.color,
    @required this.onPressed,
  })  : child = new Icon(icon, size: size, color: iconColor),
        super();

  /// Toolbar action associated with this button.
  final ZefyrToolbarAction action;

  /// Child widget to show inside this button. Usually an icon.
  final Widget child;

  /// Background color of this button.
  final Color color;

  /// Callback to trigger when this button is pressed.
  final VoidCallback onPressed;

  /// Returns `true` if this button is currently toggled on.
  bool get isToggled => color != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = theme.buttonTheme.constraints.minHeight + 4.0;
    final constraints = theme.buttonTheme.constraints.copyWith(
        minWidth: width, maxHeight: theme.buttonTheme.constraints.minHeight);
    final radius = BorderRadius.all(Radius.circular(3.0));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 6.0),
      child: RawMaterialButton(
        shape: RoundedRectangleBorder(borderRadius: radius),
        elevation: 0.0,
        fillColor: color,
        constraints: constraints,
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

/// Controls heading styles.
///
/// When pressed, this button displays overlay toolbar with three
/// buttons for each heading level.
class HeadingButton extends StatefulWidget {
  const HeadingButton({Key key}) : super(key: key);

  @override
  _HeadingButtonState createState() => _HeadingButtonState();
}

class _HeadingButtonState extends State<HeadingButton> {
  @override
  Widget build(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    return toolbar.buildButton(
      context,
      ZefyrToolbarAction.heading,
      onPressed: showOverlay,
    );
  }

  void showOverlay() {
    final toolbar = ZefyrToolbar.of(context);
    toolbar.showOverlay(buildOverlay);
  }

  Widget buildOverlay(BuildContext context) {
    final toolbar = ZefyrToolbar.of(context);
    final buttons = Row(
      children: <Widget>[
        SizedBox(width: 8.0),
        toolbar.buildButton(context, ZefyrToolbarAction.headingLevel1),
        toolbar.buildButton(context, ZefyrToolbarAction.headingLevel2),
        toolbar.buildButton(context, ZefyrToolbarAction.headingLevel3),
      ],
    );
    return ZefyrToolbarScaffold(body: buttons);
  }
}

class LinkButton extends StatefulWidget {
  const LinkButton({Key key}) : super(key: key);

  @override
  _LinkButtonState createState() => _LinkButtonState();
}

class _LinkButtonState extends State<LinkButton> {
  final TextEditingController _inputController = new TextEditingController();
  Key _inputKey;
  bool _formatError = false;
  bool get isEditing => _inputKey != null;

  @override
  Widget build(BuildContext context) {
    final editor = ZefyrEditor.of(context);
    final toolbar = ZefyrToolbar.of(context);
    final enabled =
        hasLink(editor.selectionStyle) || !editor.selection.isCollapsed;

    return toolbar.buildButton(
      context,
      ZefyrToolbarAction.link,
      onPressed: enabled ? showOverlay : null,
    );
  }

  bool hasLink(NotusStyle style) => style.contains(NotusAttribute.link);

  String getLink([String defaultValue]) {
    final editor = ZefyrEditor.of(context);
    final attrs = editor.selectionStyle;
    if (hasLink(attrs)) {
      return attrs.value(NotusAttribute.link);
    }
    return defaultValue;
  }

  void showOverlay() {
    final toolbar = ZefyrToolbar.of(context);
    toolbar.showOverlay(buildOverlay).whenComplete(cancelEdit);
  }

  void closeOverlay() {
    final toolbar = ZefyrToolbar.of(context);
    toolbar.closeOverlay();
  }

  void edit() {
    final toolbar = ZefyrToolbar.of(context);
    setState(() {
      _inputKey = new UniqueKey();
      _inputController.text = getLink('https://');
      _inputController.addListener(_handleInputChange);
      toolbar.markNeedsRebuild();
    });
  }

  void doneEdit() {
    final editor = ZefyrEditor.of(context);
    final toolbar = ZefyrToolbar.of(context);
    setState(() {
      var error = false;
      if (_inputController.text.isNotEmpty) {
        try {
          var uri = Uri.parse(_inputController.text);
          if ((uri.isScheme('https') || uri.isScheme('http')) &&
              uri.host.isNotEmpty) {
            editor.formatSelection(
                NotusAttribute.link.fromString(_inputController.text));
          } else {
            error = true;
          }
        } on FormatException {
          error = true;
        }
      }
      if (error) {
        _formatError = error;
        toolbar.markNeedsRebuild();
      } else {
        _inputKey = null;
        _inputController.text = '';
        _inputController.removeListener(_handleInputChange);
        toolbar.markNeedsRebuild();
        editor.focus(context);
      }
    });
  }

  void cancelEdit() {
    if (mounted) {
      final editor = ZefyrEditor.of(context);
      setState(() {
        _inputKey = null;
        _inputController.text = '';
        _inputController.removeListener(_handleInputChange);
        editor.focus(context);
      });
    }
  }

  void unlink() {
    final editor = ZefyrEditor.of(context);
    editor.formatSelection(NotusAttribute.link.unset);
    closeOverlay();
  }

  void copyToClipboard() {
    var link = getLink();
    assert(link != null);
    Clipboard.setData(new ClipboardData(text: link));
  }

  void openInBrowser() async {
    final editor = ZefyrEditor.of(context);
    var link = getLink();
    assert(link != null);
    if (await canLaunch(link)) {
      editor.hideKeyboard();
      await launch(link, forceWebView: true);
    }
  }

  void _handleInputChange() {
    final toolbar = ZefyrToolbar.of(context);
    setState(() {
      _formatError = false;
      toolbar.markNeedsRebuild();
    });
  }

  Widget buildOverlay(BuildContext context) {
    final editor = ZefyrEditor.of(context);
    final toolbar = ZefyrToolbar.of(context);
    final style = editor.selectionStyle;

    String value = 'Tap to edit link';
    if (style.contains(NotusAttribute.link)) {
      value = style.value(NotusAttribute.link);
    }
    final clipboardEnabled = value != 'Tap to edit link';
    final body = !isEditing
        ? _LinkView(value: value, onTap: edit)
        : _LinkInput(
            key: _inputKey,
            controller: _inputController,
            focusNode: editor.toolbarFocusNode,
            formatError: _formatError,
          );
    final items = <Widget>[Expanded(child: body)];
    if (!isEditing) {
      final unlinkHandler = hasLink(style) ? unlink : null;
      final copyHandler = clipboardEnabled ? copyToClipboard : null;
      final openHandler = hasLink(style) ? openInBrowser : null;
      final buttons = <Widget>[
        toolbar.buildButton(context, ZefyrToolbarAction.unlink,
            onPressed: unlinkHandler),
        toolbar.buildButton(context, ZefyrToolbarAction.clipboardCopy,
            onPressed: copyHandler),
        toolbar.buildButton(
          context,
          ZefyrToolbarAction.openInBrowser,
          onPressed: openHandler,
        ),
      ];
      items.addAll(buttons);
    }
    final trailingPressed = isEditing ? doneEdit : closeOverlay;
    final trailingAction =
        isEditing ? ZefyrToolbarAction.confirm : ZefyrToolbarAction.close;

    return ZefyrToolbarScaffold(
      body: Row(children: items),
      trailing: toolbar.buildButton(
        context,
        trailingAction,
        onPressed: trailingPressed,
      ),
    );
  }
}

class _LinkInput extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final bool formatError;

  const _LinkInput({
    Key key,
    @required this.focusNode,
    @required this.controller,
    this.formatError: false,
  }) : super(key: key);
  @override
  _LinkInputState createState() {
    return new _LinkInputState();
  }
}

class _LinkInputState extends State<_LinkInput> {
  bool _didAutoFocus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFocus) {
      FocusScope.of(context).requestFocus(widget.focusNode);
      _didAutoFocus = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    FocusScope.of(context).reparentIfNeeded(widget.focusNode);

    final theme = Theme.of(context);
    final toolbarTheme = ZefyrTheme.of(context).toolbarTheme;
    final color =
        widget.formatError ? Colors.redAccent : toolbarTheme.iconColor;
    final style = theme.textTheme.subhead.copyWith(color: color);
    return TextField(
      style: style,
      keyboardType: TextInputType.url,
      focusNode: widget.focusNode,
      controller: widget.controller,
      autofocus: true,
      decoration: new InputDecoration(
          hintText: 'https://',
          filled: true,
          fillColor: toolbarTheme.color,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(10.0)),
    );
  }
}

class _LinkView extends StatelessWidget {
  const _LinkView({Key key, @required this.value, this.onTap})
      : super(key: key);
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final toolbarTheme = ZefyrTheme.of(context).toolbarTheme;
    Widget widget = new ClipRect(
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          Container(
            alignment: AlignmentDirectional.centerStart,
            constraints: BoxConstraints(minHeight: ZefyrToolbar.kToolbarHeight),
            padding: const EdgeInsets.all(10.0),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.subhead
                  .copyWith(color: toolbarTheme.disabledIconColor),
            ),
          )
        ],
      ),
    );
    if (onTap != null) {
      widget = GestureDetector(
        child: widget,
        onTap: onTap,
      );
    }
    return widget;
  }
}