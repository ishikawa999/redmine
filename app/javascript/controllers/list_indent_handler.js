export default class ListIndentHandler {
  #bulletPattern = /^\s*[*+\-] /
  #orderedPattern = /^\s*\d+[.)] /

  constructor(inputElement, format) {
    this.input = inputElement
    this.format = format
  }

  run(event) {
    if (event.key !== 'Tab' || this.format !== 'common_mark') return

    const { selectionStart, value } = this.input
    const lineStart = value.lastIndexOf("\n", selectionStart - 1) + 1
    const currentLine = value.slice(lineStart, selectionStart)
    const spaces = this.#indentSize(currentLine)
    if (!spaces) return

    event.preventDefault()
    event.shiftKey
      ? this.#unindent(lineStart, currentLine, selectionStart, spaces)
      : this.#indent(lineStart, selectionStart, spaces)
  }

  #indentSize(line) {
    if (this.#bulletPattern.test(line)) return 2
    if (this.#orderedPattern.test(line)) return 4
    return 0
  }

  #indent(lineStart, cursorPos, spaces) {
    this.input.setRangeText(' '.repeat(spaces), lineStart, lineStart, 'preserve')
    this.input.setSelectionRange(cursorPos + spaces, cursorPos + spaces)
  }

  #unindent(lineStart, currentLine, cursorPos, spaces) {
    const currentIndent = currentLine.match(/^(\s*)/)[1].length
    const remove = Math.min(spaces, currentIndent)
    if (remove === 0) return
    this.input.setRangeText('', lineStart, lineStart + remove, 'preserve')
    const newCursor = Math.max(lineStart, cursorPos - remove)
    this.input.setSelectionRange(newCursor, newCursor)
  }
}
