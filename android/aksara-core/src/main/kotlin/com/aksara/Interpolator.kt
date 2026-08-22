package com.aksara

/**
 * Replaces `{{var}}` placeholders in a template with values from [args].
 *
 * - Whitespace inside the braces is tolerated: `{{ name }}` == `{{name}}`.
 * - A missing variable leaves the placeholder **intact** (`{{name}}`) rather than
 *   silently dropping it — a visible gap is easier to catch than an empty string.
 * - Fast path: templates with no `{{` (or empty args) are returned untouched.
 *
 * Mirror of the Swift `Interpolator`.
 */
internal object Interpolator {
    fun interpolate(template: String, args: Map<String, String>): String {
        if (args.isEmpty() || !template.contains("{{")) return template

        val result = StringBuilder(template.length)
        var index = 0
        while (index < template.length) {
            val open = template.indexOf("{{", index)
            if (open < 0) {
                result.append(template, index, template.length)
                break
            }
            result.append(template, index, open)
            val close = template.indexOf("}}", open + 2)
            if (close < 0) {
                // Unterminated placeholder — emit the remainder verbatim and stop.
                result.append(template, open, template.length)
                break
            }
            val rawName = template.substring(open + 2, close)
            val name = rawName.trim()
            val value = args[name]
            if (value != null) result.append(value) else result.append("{{").append(rawName).append("}}")
            index = close + 2
        }
        return result.toString()
    }
}
