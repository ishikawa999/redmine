export default class ListIndentHandler {
  constructor(inputElement, format) {
    this.input = inputElement
    this.format = format
  }

  run(event) {
    if (event.key !== 'Tab') return

    const { selectionStart, value } = this.input
    const beforeCursor = value.slice(0, selectionStart)
    const lineStart = beforeCursor.lastIndexOf("\n") + 1
    const currentLine = beforeCursor.slice(lineStart)

    if (!this.#isListLine(currentLine)) return

    event.preventDefault()

    if (event.shiftKey) {
      this.#unindent(lineStart, currentLine, selectionStart)
    } else {
      this.#indent(lineStart, selectionStart)
    }
  }

  #isListLine(line) {
    switch (this.format) {
      case 'common_mark':
        return /^\s*[*+\-] /.test(line) || /^\s*\d+[.)] /.test(line)
      case 'textile':
        return /^[*#]+ /.test(line)
      default:
        return false
    }
  }

  #indent(lineStart, cursorPos) {
    this.input.setRangeText('  ', lineStart, lineStart, 'preserve')
    this.input.setSelectionRange(cursorPos + 2, cursorPos + 2)
  }

  #unindent(lineStart, currentLine, cursorPos) {
    const match = currentLine.match(/^( {1,2})/)
    if (!match) return

    const spacesToRemove = match[1].length
    this.input.setRangeText('', lineStart, lineStart + spacesToRemove, 'preserve')
    const newCursor = Math.max(lineStart, cursorPos - spacesToRemove)
    this.input.setSelectionRange(newCursor, newCursor)
  }
}
