import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  #bulletPattern = /^\s*[*+\-] /
  #orderedPattern = /^\s*\d+[.)] /

  run(event) {
    const format = event.params.textFormatting
    if (format !== 'common_mark') return

    const input = event.currentTarget
    const { selectionStart, value } = input
    const lineStart = value.lastIndexOf("\n", selectionStart - 1) + 1
    const lineEnd = value.indexOf("\n", selectionStart)
    const currentLine = value.slice(lineStart, lineEnd === -1 ? value.length : lineEnd)
    const spaces = this.#indentSize(currentLine)
    if (!spaces) return

    event.preventDefault()
    event.shiftKey
      ? this.#unindent(input, lineStart, currentLine, selectionStart, spaces)
      : this.#indent(input, lineStart, selectionStart, spaces)
  }

  #indentSize(line) {
    if (this.#bulletPattern.test(line)) return 2
    if (this.#orderedPattern.test(line)) return 4
    return 0
  }

  #indent(input, lineStart, cursorPos, spaces) {
    input.setRangeText(' '.repeat(spaces), lineStart, lineStart, 'preserve')
    input.setSelectionRange(cursorPos + spaces, cursorPos + spaces)
  }

  #unindent(input, lineStart, currentLine, cursorPos, spaces) {
    const currentIndent = currentLine.match(/^(\s*)/)[1].length
    const remove = Math.min(spaces, currentIndent)
    if (remove === 0) return
    input.setRangeText('', lineStart, lineStart + remove, 'preserve')
    const newCursor = Math.max(lineStart, cursorPos - remove)
    input.setSelectionRange(newCursor, newCursor)
  }
}
