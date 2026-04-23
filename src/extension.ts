import * as vscode from 'vscode';
import * as path from 'path';

let sharedTerminal: vscode.Terminal | undefined;

function getReuseTerminalSetting(): boolean {
	return vscode.workspace.getConfiguration('runbatastask').get<boolean>('reuseTerminal', true);
}

function createRunTerminal(cwd: string, reuseTerminal: boolean): vscode.Terminal {
	if (reuseTerminal && sharedTerminal) {
		// VS Code does not support changing cwd for an existing terminal reliably.
		// Disposing ensures we keep a single visible terminal tab without accumulating many.
		sharedTerminal.dispose();
		sharedTerminal = undefined;
	}

	const terminal = vscode.window.createTerminal({ name: 'Run Script', cwd });
	if (reuseTerminal) {
		sharedTerminal = terminal;
	}
	return terminal;
}

export function activate(context: vscode.ExtensionContext): void {
	context.subscriptions.push(
		vscode.window.onDidCloseTerminal((t) => {
			if (t === sharedTerminal) {
				sharedTerminal = undefined;
			}
		})
	);

	context.subscriptions.push(
		vscode.commands.registerCommand('runbatastask.runAsTask', () => {
			const doc = vscode.window.activeTextEditor?.document;
			const ext = path.extname(doc?.uri.fsPath ?? '').toLowerCase();
			if (ext !== '.bat' && ext !== '.cmd' && ext !== '.ps1') {
				return;
			}
			const cwd = path.dirname(doc!.uri.fsPath);
			const name = path.basename(doc!.uri.fsPath);
			const term = createRunTerminal(cwd, getReuseTerminalSetting());
			term.show();
			if (ext === '.ps1') {
				if (process.platform === 'win32') {
					term.sendText(`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${name}"`);
				} else {
					term.sendText(`pwsh -NoProfile -File "${name}"`);
				}
			} else {
				term.sendText(process.platform === 'win32' ? `cmd /c "${name}"` : name);
			}
		})
	);
}

export function deactivate(): void {}
