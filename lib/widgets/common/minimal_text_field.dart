import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MinimalTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final IconData? icon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool showLabel;
  final String? prefix;
  
  const MinimalTextField({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.icon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.obscureText = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.autofillHints,
    this.validator,
    this.showLabel = true,
    this.prefix,
  });

  @override
  State<MinimalTextField> createState() => _MinimalTextFieldState();
}

class _MinimalTextFieldState extends State<MinimalTextField> {
  bool _obscureText = true;
  late FocusNode _focusNode;
  bool _isFocused = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null && widget.showLabel) ...[
          Text(
            widget.label!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Container without clipping to prevent border cutoff
        Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03), // Match other text fields
              border: Border.all(
                color: _errorText != null
                  ? Colors.red.withValues(alpha: 0.5)
                  : _isFocused 
                    ? Colors.blue.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.08),
                width: _isFocused ? 1.0 : 0.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Left icon section with proper centering
                if (widget.icon != null) ...[
                  Container(
                    width: 50, // Fixed width for centering
                    alignment: Alignment.center,
                    child: Icon(
                      widget.icon,
                      color: _isFocused 
                        ? Colors.blue.withValues(alpha: 0.7)
                        : const Color(0xFF94A3B8).withValues(alpha: 0.5),
                      size: 18,
                    ),
                  ),
                ],
                // Text input area
                Expanded(
                  child: TextFormField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          obscureText: widget.obscureText && _obscureText,
                          validator: (value) {
                            if (widget.validator != null) {
                              final error = widget.validator!(value);
                              // Update error state but don't show error in decoration
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() {
                                    _errorText = error;
                                  });
                                }
                              });
                              return error;
                            }
                            return null;
                          },
                          textInputAction: widget.textInputAction,
                          onFieldSubmitted: widget.onFieldSubmitted,
                          onChanged: widget.onChanged,
                          keyboardType: widget.keyboardType,
                          inputFormatters: widget.inputFormatters,
                          autocorrect: false,
                          enableSuggestions: false,
                          autofillHints: widget.autofillHints,
                          scrollController: ScrollController(),
                          scrollPhysics: const ClampingScrollPhysics(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            prefixText: widget.prefix,
                            prefixStyle: TextStyle(
                              color: const Color(0xFF94A3B8).withValues(alpha: 0.67),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            hintText: widget.placeholder,
                            hintStyle: TextStyle(
                              color: const Color(0xFF94A3B8).withValues(alpha: 0.67),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            errorStyle: const TextStyle(height: 0, fontSize: 0), // Hide error text
                            contentPadding: EdgeInsets.only(
                              left: widget.icon != null ? 0 : 16,
                              right: (widget.obscureText || widget.suffixIcon != null) ? 0 : 16,
                              top: 8,
                              bottom: 8,
                            ),
                          ),
                        ),
                ),
                      // Right icon section with proper centering
                      if (widget.obscureText) 
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                          child: Container(
                            width: 50, // Fixed width for centering
                            alignment: Alignment.center,
                            child: Icon(
                              _obscureText ? Icons.visibility_off : Icons.visibility,
                              color: _isFocused 
                                ? Colors.blue.withValues(alpha: 0.7)
                                : const Color(0xFF94A3B8).withValues(alpha: 0.5),
                              size: 18,
                            ),
                          ),
                        )
                      else if (widget.suffixIcon != null)
                        GestureDetector(
                          onTap: widget.onSuffixIconTap,
                          child: Container(
                            width: 50, // Fixed width for centering
                            alignment: Alignment.center,
                            child: Icon(
                              widget.suffixIcon,
                              color: _isFocused 
                                ? Colors.blue.withValues(alpha: 0.7)
                                : const Color(0xFF94A3B8).withValues(alpha: 0.5),
                              size: 18,
                            ),
                          ),
                        ),
              ],
            ),
        ),
        // Error text below the field
        if (_errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _errorText!,
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
  }
}