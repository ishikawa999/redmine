class CommandPalette {
  constructor({ triggerKeyCombo }) {
    document.addEventListener('DOMContentLoaded', () => {
      this.palette = document.getElementById('commandPalette');
      this.input = document.getElementById('commandInput');
      this.list = document.getElementById('commandList');
      this.items = this.list.querySelectorAll('li');
      this.triggerKeyCombo = triggerKeyCombo;
      this.selectedIndex = -1;

      if (!this.palette || !this.input || !this.list || !this.items) {
        console.error('Command Palette elements are missing in the DOM.');
        return;
      }

      this.init();
    });
  }

  init() {
    document.addEventListener('keydown', (event) => {
      if (this.isTriggerKeyCombo(event)) {
        event.preventDefault();
        this.togglePalette();
      }
    });

    this.input.addEventListener('input', () => {
      this.filterCommands();
    });

    // キーボード操作（矢印キーとEnter）
    this.input.addEventListener('keydown', (event) => {
      if (event.key === 'ArrowDown') {
        this.navigateCommands(1);
        event.preventDefault();
      } else if (event.key === 'ArrowUp') {
        this.navigateCommands(-1);
        event.preventDefault();
      } else if (event.key === 'Enter') {
        this.executeSelectedCommand();
        event.preventDefault();
      }
    });

    this.list.addEventListener('click', (event) => {
      const clickedItem = event.target.closest('li');
      if (clickedItem) {
        this.selectCommandByItem(clickedItem);
        this.executeSelectedCommand();
      }
    });

    document.addEventListener('click', (event) => {
      if (this.palette.style.display === 'block' && !this.palette.contains(event.target)) {
        this.closePalette();
      }
    });
  }

  isTriggerKeyCombo(event) {
    return (event.ctrlKey || event.metaKey) && event.shiftKey && event.code === this.triggerKeyCombo;
  }

  togglePalette() {
    if (this.palette.style.display === 'block') {
      this.closePalette();
    } else {
      this.openPalette();
    }
  }

  openPalette() {
    this.palette.style.display = 'block';
    this.input.focus();
    this.filterCommands();
  }

  closePalette() {
    this.palette.style.display = 'none';
    this.input.value = '';
    this.items.forEach((item) => (item.style.display = 'block'));
    this.selectedIndex = -1;
  }

  filterCommands() {
    const query = this.input.value.toLowerCase();
    this.items.forEach((item) => {
      const text = item.textContent.toLowerCase();
      item.style.display = text.includes(query) ? 'block' : 'none';
    });
    this.selectCommandByIndex(0);
  }

  navigateCommands(direction) {
    const visibleItems = Array.from(this.items).filter((item) => item.style.display !== 'none');
    if (visibleItems.length === 0) return;

    const newIndex = (this.selectedIndex + direction + visibleItems.length) % visibleItems.length;
    this.selectCommandByIndex(newIndex);
  }

  selectCommandByItem(item) {
    const visibleItems = Array.from(this.items).filter((item) => item.style.display !== 'none');
    const index = visibleItems.indexOf(item);
  
    if (index === -1) {
      return;
    }
  
    this._applySelection(visibleItems, index);
  }
  
  selectCommandByIndex(index) {
    const visibleItems = Array.from(this.items).filter((item) => item.style.display !== 'none');
  
    if (index < 0 || index >= visibleItems.length) {
      return;
    }
  
    this._applySelection(visibleItems, index);
  }

  _applySelection(visibleItems, index) {
    this.items.forEach((item) => item.classList.remove('selected'));

    this.selectedIndex = index;
    visibleItems[this.selectedIndex].classList.add('selected');
  }

  executeSelectedCommand() {
    const visibleItems = Array.from(this.items).filter((item) => item.style.display !== 'none');
    if (this.selectedIndex >= 0 && visibleItems[this.selectedIndex]) {
      const link = visibleItems[this.selectedIndex].querySelector('a');
      if (link) {
        link.click();
        this.closePalette();
      }
    }
  }
}

const commandPalette = new CommandPalette({
  triggerKeyCombo: 'KeyP'
});
