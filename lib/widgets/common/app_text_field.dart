import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? label;
  final String? placeholder;
  final IconData? icon;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final List<String>? autofillHints;
  final String? Function(String?)? validator;
  final bool flatLeftCorners;

  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.placeholder,
    this.icon,
    this.obscureText = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.autofillHints,
    this.validator,
    this.flatLeftCorners = false,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
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
        Container(
          decoration: BoxDecoration(
            // Glassmorphic frosted glass effect
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
            borderRadius: widget.flatLeftCorners
                ? const BorderRadius.only(
                    topLeft: Radius.circular(0),
                    bottomLeft: Radius.circular(0),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  )
                : BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.05),
                blurRadius: 1,
                offset: const Offset(0, 1),
                spreadRadius: 0,
                blurStyle: BlurStyle.inner,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: widget.flatLeftCorners
                ? const BorderRadius.only(
                    topLeft: Radius.circular(0),
                    bottomLeft: Radius.circular(0),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  )
                : BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Row(
                children: [
                  if (widget.icon != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: Icon(
                        widget.icon,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: TextFormField(
                      controller: widget.controller,
                      obscureText: widget.obscureText && _obscureText,
                      textInputAction: widget.textInputAction,
                      onFieldSubmitted: widget.onFieldSubmitted,
                      onChanged: widget.onChanged,
                      keyboardType: widget.keyboardType,
                      inputFormatters: widget.inputFormatters,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: widget.autofillHints,
                      validator: widget.validator,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: widget.icon != null ? 0 : 20,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                  if (widget.obscureText)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                        splashRadius: 20,
                        tooltip:
                            _obscureText ? 'Show password' : 'Hide password',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
