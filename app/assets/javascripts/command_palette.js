class CommandPalette {
  constructor({ triggerKeyCombo }) {
    document.addEventListener('DOMContentLoaded', () => {
      this.palette = document.getElementById('commandPalette');
      this.input = document.getElementById('commandInput');
      this.list = document.getElementById('commandList');
      this.items = this.list.querySelectorAll('li'); // 事前定義された `li` 要素を取得
      this.triggerKeyCombo = triggerKeyCombo;
      this.selectedIndex = -1; // 現在選択中のコマンドのインデックス

      if (!this.palette || !this.input || !this.list || !this.items) {
        console.error('Command Palette elements are missing in the DOM.');
        return;
      }

      this.init();
    });
  }

  init() {
    // ショートカットキーで表示トグル
    document.addEventListener('keydown', (event) => {
      if (this.isTriggerKeyCombo(event)) {
        event.preventDefault();
        this.togglePalette();
      }
    });

    // 入力フィルタリング
    this.input.addEventListener('input', () => {
      this.filterCommands();
      this.selectedIndex = -1; // 入力時は選択解除
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

    // コマンド選択時のアクション実行（クリック時）
    this.list.addEventListener('click', (event) => {
      const clickedItem = event.target.closest('li');
      if (clickedItem) {
        this.selectCommand(clickedItem);
        this.executeSelectedCommand();
      }
    });

    // 外部クリックで非表示
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
    this.filterCommands(); // 初回表示時にフィルタをリセット
  }

  closePalette() {
    this.palette.style.display = 'none';
    this.input.value = '';
    this.items.forEach((item) => (item.style.display = 'block')); // 全アイテムを表示
    this.selectedIndex = -1; // 選択状態をリセット
  }

  filterCommands() {
    const query = this.input.value.toLowerCase();
    this.items.forEach((item) => {
      const text = item.textContent.toLowerCase();
      item.style.display = text.includes(query) ? 'block' : 'none'; // フィルタリング
    });
  }

  navigateCommands(direction) {
    const visibleItems = Array.from(this.items).filter((item) => item.style.display !== 'none');
    if (visibleItems.length === 0) return;

    // 現在の選択を解除
    if (this.selectedIndex >= 0) {
      visibleItems[this.selectedIndex].classList.remove('selected');
    }

    // 新しい選択位置を計算
    this.selectedIndex = (this.selectedIndex + direction + visibleItems.length) % visibleItems.length;

    // 新しい選択を適用
    visibleItems[this.selectedIndex].classList.add('selected');
    visibleItems[this.selectedIndex].scrollIntoView({ block: 'nearest' });
  }

  selectCommand(item) {
    const visibleItems = Array.from(this.items).filter((item) => item.style.display !== 'none');
    const index = visibleItems.indexOf(item);

    if (index !== -1) {
      // 現在の選択を解除
      if (this.selectedIndex >= 0) {
        visibleItems[this.selectedIndex].classList.remove('selected');
      }

      // 新しい選択を適用
      this.selectedIndex = index;
      visibleItems[this.selectedIndex].classList.add('selected');
    }
  }

  executeSelectedCommand() {
    const visibleItems = Array.from(this.items).filter((item) => item.style.display !== 'none');
    if (this.selectedIndex >= 0 && visibleItems[this.selectedIndex]) {
      const link = visibleItems[this.selectedIndex].querySelector('a');
      if (link) {
        link.click(); // 選択されたリンクをクリック
        this.closePalette();
      }
    }
  }
}

// コマンドパレットの初期化
const commandPalette = new CommandPalette({
  triggerKeyCombo: 'KeyP'
});
