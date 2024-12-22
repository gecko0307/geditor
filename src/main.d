module main;

import core.thread;
import std.stdio;
import std.socket;
import std.array;
import std.algorithm;
import std.path;
import std.file;
import std.process;
import std.conv;
import std.string;
import std.utf;

import dlangui;
import dlangui.core.linestream;
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;
import fswatch;
import myers_diff;
import syntax.dlang;

mixin APP_ENTRY_POINT;

// action codes
enum IDEActions: int {
    FileNew = 1010000,
    FileOpen,
    FileSave,
    FileSaveAs,
    FileSaveAll,
    FileClose,
    FileExit,
    EditTabsToSpaces,
    EditSpacesToTabs,
    EditPreferences,
    ViewTheme,
    ViewThemeLight,
    ViewThemeDark,
    WindowMinimize,
    WindowMaximize,
    WindowRestore,
    ToolsLineEndings,
    ToolsLineEndingLF,
    ToolsLineEndingCRLF,
    HelpViewHelp,
    HelpAbout,
    ServerOpen
}

// Actions
const Action ACTION_FILE_NEW = new Action(IDEActions.FileNew, "MENU_FILE_NEW"c, "document-new", KeyCode.KEY_N, KeyFlag.Control);
const Action ACTION_FILE_SAVE = (new Action(IDEActions.FileSave, "MENU_FILE_SAVE"c, "document-save", KeyCode.KEY_S, KeyFlag.Control)).disableByDefault();
const Action ACTION_FILE_SAVE_AS = new Action(IDEActions.FileSaveAs, "MENU_FILE_SAVE_AS"c);
const Action ACTION_FILE_OPEN = new Action(IDEActions.FileOpen, "MENU_FILE_OPEN"c, "document-open", KeyCode.KEY_O, KeyFlag.Control);
const Action ACTION_FILE_EXIT = new Action(IDEActions.FileExit, "MENU_FILE_EXIT"c, "document-close"c, KeyCode.KEY_X, KeyFlag.Alt);

const Action ACTION_VIEW_THEME = new Action(IDEActions.ViewTheme, "MENU_VIEW_THEME"c, "view-theme"c);
const Action ACTION_VIEW_THEME_DEFAULT = new Action(IDEActions.ViewThemeLight, "MENU_VIEW_THEME_DEFAULT"c, "view-theme-default");
const Action ACTION_VIEW_THEME_DARK = new Action(IDEActions.ViewThemeDark, "MENU_VIEW_THEME_DARK"c, "view-theme-dark");

const Action ACTION_EDIT_COPY = (new Action(EditorActions.Copy, "MENU_EDIT_COPY"c, "edit-copy"c, KeyCode.KEY_C, KeyFlag.Control)).addAccelerator(KeyCode.INS, KeyFlag.Control).disableByDefault();
const Action ACTION_EDIT_PASTE = (new Action(EditorActions.Paste, "MENU_EDIT_PASTE"c, "edit-paste"c, KeyCode.KEY_V, KeyFlag.Control)).addAccelerator(KeyCode.INS, KeyFlag.Shift).disableByDefault();
const Action ACTION_EDIT_CUT = (new Action(EditorActions.Cut, "MENU_EDIT_CUT"c, "edit-cut"c, KeyCode.KEY_X, KeyFlag.Control)).addAccelerator(KeyCode.DEL, KeyFlag.Shift).disableByDefault();
const Action ACTION_EDIT_UNDO = (new Action(EditorActions.Undo, "MENU_EDIT_UNDO"c, "edit-undo"c, KeyCode.KEY_Z, KeyFlag.Control)).disableByDefault();
const Action ACTION_EDIT_REDO = (new Action(EditorActions.Redo, "MENU_EDIT_REDO"c, "edit-redo"c, KeyCode.KEY_Y, KeyFlag.Control)).addAccelerator(KeyCode.KEY_Z, KeyFlag.Control).disableByDefault();
const Action ACTION_EDIT_INDENT = (new Action(EditorActions.Indent, "MENU_EDIT_INDENT"c, "edit-indent"c, KeyCode.KEY_BRACKETCLOSE, KeyFlag.Control)).addAccelerator(KeyCode.TAB);
const Action ACTION_EDIT_UNINDENT = (new Action(EditorActions.Unindent, "MENU_EDIT_UNINDENT"c, "edit-unindent", KeyCode.KEY_BRACKETOPEN, KeyFlag.Control));
const Action ACTION_EDIT_TOGGLE_LINE_COMMENT = (new Action(EditorActions.ToggleLineComment, "MENU_EDIT_TOGGLE_LINE_COMMENT"c, null, KeyCode.KEY_DIVIDE, KeyFlag.Control)).disableByDefault();
const Action ACTION_EDIT_TOGGLE_BLOCK_COMMENT = (new Action(EditorActions.ToggleBlockComment, "MENU_EDIT_TOGGLE_BLOCK_COMMENT"c, null, KeyCode.KEY_DIVIDE, KeyFlag.Control)).disableByDefault();
const Action ACTION_EDIT_TABS_TO_SPACES = (new Action(IDEActions.EditTabsToSpaces, "MENU_EDIT_TABS_TO_SPACES"c, "edit-tabs-to-spaces"c));
const Action ACTION_EDIT_SPACES_TO_TABS = (new Action(IDEActions.EditSpacesToTabs, "MENU_EDIT_SPACES_TO_TABS"c, "edit-spaces-to-tabs"c));
const Action ACTION_EDIT_PREFERENCES = (new Action(IDEActions.EditPreferences, "MENU_EDIT_PREFERENCES"c, null)).disableByDefault();

const ACTION_TOOLS_LINE_ENDINGS = new Action(IDEActions.ToolsLineEndings, "MENU_TOOLS_LINE_ENDINGS"c);
const ACTION_TOOLS_LINE_ENDING_LF = new Action(IDEActions.ToolsLineEndingLF, "MENU_TOOLS_LINE_ENDING_LF"c);
const ACTION_TOOLS_LINE_ENDING_CRLF = new Action(IDEActions.ToolsLineEndingCRLF, "MENU_TOOLS_LINE_ENDING_CRLF"c);

const Action ACTION_WINDOW_MINIMIZE = new Action(IDEActions.WindowMinimize, "MENU_WINDOW_MINIMIZE"c);
const Action ACTION_WINDOW_MAXIMIZE = new Action(IDEActions.WindowMaximize, "MENU_WINDOW_MAXIMIZE"c);
const Action ACTION_WINDOW_RESTORE = new Action(IDEActions.WindowRestore, "MENU_WINDOW_RESTORE"c);
const Action ACTION_HELP_VIEW_HELP = new Action(IDEActions.HelpViewHelp, "MENU_HELP_VIEW_HELP"c);
const Action ACTION_HELP_ABOUT = new Action(IDEActions.HelpAbout, "MENU_HELP_ABOUT"c);

const Action ACTION_SERVER_OPEN = new Action(IDEActions.ServerOpen, "SERVER_OPEN"c, "server-open");

Widget createEditorSettingsControl(EditWidgetBase editor) {
    HorizontalLayout res = new HorizontalLayout("editor_options");
    res.addChild((new CheckBox("wantTabs", "wantTabs"d)).checked(editor.wantTabs).addOnCheckChangeListener(delegate(Widget, bool checked) { editor.wantTabs = checked; return true;}));
    res.addChild((new CheckBox("useSpacesForTabs", "useSpacesForTabs"d)).checked(editor.useSpacesForTabs).addOnCheckChangeListener(delegate(Widget, bool checked) { editor.useSpacesForTabs = checked; return true;}));
    res.addChild((new CheckBox("readOnly", "readOnly"d)).checked(editor.readOnly).addOnCheckChangeListener(delegate(Widget, bool checked) { editor.readOnly = checked; return true;}));
    res.addChild((new CheckBox("showLineNumbers", "showLineNumbers"d)).checked(editor.showLineNumbers).addOnCheckChangeListener(delegate(Widget, bool checked) { editor.showLineNumbers = checked; return true;}));
    res.addChild((new CheckBox("fixedFont", "fixedFont"d)).checked(editor.fontFamily == FontFamily.MonoSpace).addOnCheckChangeListener(delegate(Widget, bool checked) {
        if (checked)
            editor.fontFamily(FontFamily.MonoSpace).fontFace("Courier New");
        else
            editor.fontFamily(FontFamily.SansSerif).fontFace("Arial");
        return true;
    }));
    res.addChild((new CheckBox("tabSize", "Tab size 8"d)).checked(editor.tabSize == 8).addOnCheckChangeListener(delegate(Widget, bool checked) {
        if (checked)
            editor.tabSize(8);
        else
            editor.tabSize(4);
        return true;
    }));
    return res;
}

auto dstringLineDiff(dstring[] a, dstring[] b)
{
    return MyersDiff!dstring.getDiff(a.dup, b.dup);
}

class GESourceEdit: SourceEdit
{
    DSyntaxSupport tokenizer;
    GTabContent tabContent;
    GESourceEdit syncEditor;
    LineEnding lineEnding = LineEnding.CRLF;
    MyersDiff!dstring.DiffResult[] diff;
    uint diffColor = 0xff9d9d;
    
    this(GTabContent tabContent, string id)
    {
        super(id);
        
        this.tabContent = tabContent;
        
        MenuItem editPopupItem = new MenuItem(null);
        editPopupItem.add(
            ACTION_EDIT_COPY,
            ACTION_EDIT_PASTE,
            ACTION_EDIT_CUT,
            ACTION_EDIT_UNDO,
            ACTION_EDIT_REDO,
            ACTION_EDIT_INDENT,
            ACTION_EDIT_UNINDENT,
            ACTION_EDIT_TOGGLE_LINE_COMMENT);
        popupMenu = editPopupItem;
        
        hscrollbarMode = ScrollBarMode.Auto;
        vscrollbarMode = ScrollBarMode.Auto;
        
        fontFace = "Consolas,Liberation Mono,monospace";
        fontSize = makePointSize(11);
        showIcons = true;
        useSpacesForTabs = true;
        tabSize = 4;
        showWhiteSpaceMarks = true;
        smartIndents = true;
        showTabPositionMarks = true;
        //showIcons = true;
        //showFolding = true;
        
        tokenizer = new DSyntaxSupport();
        content.syntaxSupport = tokenizer;

        setTokenHightlightColor(TokenCategory.Comment, style.customColor("editor_syntax_comment", 0x007f00));
        setTokenHightlightColor(TokenCategory.Keyword, style.customColor("editor_syntax_keyword", 0x3300ff));
        setTokenHightlightColor(TokenCategory.String, style.customColor("editor_syntax_string", 0x7f007f));
        setTokenHightlightColor(TokenCategory.Integer, style.customColor("editor_syntax_number", 0x007f7f));
        setTokenHightlightColor(TokenCategory.Float, style.customColor("editor_syntax_number", 0x007f7f));
        setTokenHightlightColor(TokenCategory.Error, style.customColor("editor_syntax_error", 0xff0000));
        setTokenHightlightColor(TokenCategory.Op, style.customColor("editor_syntax_op", 0x503000));
        setTokenHightlightColor(TokenCategory.Identifier_Class, style.customColor("editor_syntax_class", 0x000080));
        
        //onThemeChanged();
    }
    
    override bool handleActionStateRequest(const Action a) {
        switch (a.id)
        {
            case IDEActions.FileSaveAs:
                a.state = ACTION_STATE_ENABLED;
                return true;
            case IDEActions.FileSave:
                if (_content.modified)
                    a.state = ACTION_STATE_ENABLED;
                else
                    a.state = ACTION_STATE_DISABLE;
                return true;
            default:
                return super.handleActionStateRequest(a);
        }
    }
    
    override bool onMouseEvent(MouseEvent event)
    {
        if (syncEditor)
        {
            if (event.action == MouseAction.Wheel)
                syncEditor.onMouseEvent(event);
        }
        return super.onMouseEvent(event);
    }
    
    override bool onVScroll(ScrollEvent event)
    {
        super.onVScroll(event);
        if (syncEditor)
        {
            syncEditor.vscrollbar.position = vscrollbar.position;
            syncEditor.vscrollbar.sendScrollEvent(event.action, vscrollbar.position);
        }
        return true;
    }
    
    override bool onHScroll(ScrollEvent event)
    {
        super.onHScroll(event);
        if (syncEditor)
        {
            syncEditor.hscrollbar.position = hscrollbar.position;
            syncEditor.hscrollbar.sendScrollEvent(event.action, hscrollbar.position);
        }
        return true;
    }
    
    override void onContentChange(
        EditableContent content,
        EditOperation operation,
        ref TextRange rangeBefore,
        ref TextRange rangeAfter,
        Object source)
    {
        super.onContentChange(content, operation, rangeBefore, rangeAfter, source);
        if (syncEditor)
        {
            dstring textLeft = text;
            dstring textRight = syncEditor.text;
            syncEditor.diff = dstringLineDiff(textRight.splitLines, textLeft.splitLines);
        }
    }
    
    override void drawLineBackground(DrawBuf buf, int lineIndex, Rect lineRect, Rect visibleRect)
    {
        super.drawLineBackground(buf, lineIndex, lineRect, visibleRect);
        Rect rc = lineRect;
        foreach(ref d; diff)
        {
            if (d.pos == lineIndex)
            {
                buf.fillRect(rc, diffColor);
            }
        }
    }
    
    void detectIndentation()
    {
        auto lines = text.splitLines();
        size_t spaces = 0;
        size_t tabs = 0;

        foreach (line; lines)
        {
            foreach (c; line)
            {
                if (c == ' ')
                {
                    spaces++;
                }
                else if (c == '\t')
                {
                    tabs++;
                }
                else
                {
                    break;
                }
            }
        }
        
        // TODO: make global setting, allow the user to change
        if (spaces > tabs)
        {
            useSpacesForTabs = true;
        }
        else
        {
            useSpacesForTabs = false;
        }
    }
}

class GTabContent: HorizontalLayout
{
    GESourceEdit editor;
    ResizerWidget resizer;
    GESourceEdit editorRight;
    string filename;
    
    this(string filename)
    {
        super(filename);
        this.filename = filename;
        editor = new GESourceEdit(this, filename);
        resizer = new ResizerWidget(filename);
        editorRight = new GESourceEdit(this, filename);
        editor.text = ""d;
        editorRight.text = ""d;
        editorRight.enabled = false;
        editor.syncEditor = editorRight;
        addChild(editor);
        addChild(resizer);
        addChild(editorRight);
        layoutHeight(FILL_PARENT);
        layoutWidth(FILL_PARENT);
    }
    
    ~this()
    {
        destroy(editor);
    }
}

GTabContent newFile(TabWidget tabs, string filename, int num = 1)
{
    string tabName = baseName(filename);
    GTabContent tabContent = new GTabContent(tabName);
    int index = tabs.tabIndex(filename);
    if (index >= 0)
    {
        // File is already opened in another tab, close it
        tabs.removeTab(filename);
    }
    tabs.addTab(tabContent, toUTF32(tabName), null, true);
    tabs.selectTab(filename);
    return tabContent;
}

auto git(string[] args, string workingDir)
{
    return execute(["git"] ~ args, null, std.process.Config(std.process.Config.Flags.suppressConsole), 18446744073709551615LU, workingDir);
}

auto gitShow(string filename)
{
    string workingDir = dirName(filename);
    string name = baseName(filename);
    return git(["show", "HEAD:./" ~ name], workingDir);
}

GTabContent openFile(TabWidget tabs, string filename)
{
    int index = tabs.tabIndex(filename);
    if (index >= 0)
    {
        // File is already opened in tab, select it
        tabs.selectTab(index, true);
        Widget tabBody = tabs.selectedTabBody();
        return cast(GTabContent)tabBody;
    }
    else
    {
        // Create a new tab and load file
        GTabContent tabContent = new GTabContent(filename);
        if (tabContent.editor.load(filename))
        {
            tabContent.editor.detectIndentation();
            
            auto show = gitShow(filename);
            if (show.status == 0)
            {
                tabContent.editorRight.text = toUTF32(show.output);
            }
            else
            {
                tabContent.editorRight.load(filename);
            }
            
            dstring textLeft = tabContent.editor.text;
            dstring textRight = tabContent.editorRight.text;
            tabContent.editorRight.diff = dstringLineDiff(textRight.splitLines, textLeft.splitLines);
            
            string tabName = baseName(filename);
            tabs.addTab(tabContent, toUTF32(tabName), null, true);
            tabs.selectTab(filename);
            TabItem tab = tabs.selectedTab;
            return tabContent;
        }
        else
        {
            destroy(tabContent);
            return null;
        }
    }
}

dstring replaceLFtoCRLF(dstring input)
{
    return input.replace("\n", "\r\n").replace("\r\r\n", "\r\n");
}

dstring replaceCRLFtoLF(dstring input)
{
    return input.replace("\r\n", "\n");
}

__gshared Window window;

class SIAServerThread: Thread
{
    __gshared bool running = true;
    string host = "127.0.0.1";
    ushort port = 9988;
    __gshared Socket listener;
    
    this()
    {
        super(&threadProc);
        isDaemon = false;
    }
    
    bool run(string newFilename = "")
    {
        try
        {
            listener = new TcpSocket(AddressFamily.INET);
            listener.bind(new InternetAddress(host, port));
            listener.blocking = true;
            if (listener) start();
            return true;
        }
        catch (SocketOSException e)
        {
            if (e.errorCode == EADDRINUSE)
            {
                if (newFilename.length)
                {
                    auto client = new TcpSocket(AddressFamily.INET);
                    client.connect(new InternetAddress(host, port));
                    client.send(newFilename.representation);
                    client.close();
                }
                
                return false;
            }
            else
                return true;
        }
    }
    
    void threadProc()
    {
        listener.listen(1);
        while(running)
        {
            Socket client = listener.accept();
            if (client)
            {
                char[1024] buf;
                auto numBytes = client.receive(buf);
                string newFilename = cast(string)buf[0..numBytes];
                Action a = new Action(IDEActions.ServerOpen, "SERVER_OPEN"c, "server-open");
                a.stringParam = newFilename;
                window.dispatchAction(a);
                client.close();
            }
        }
    }
    
    void close()
    {
        listener.close();
        running = false;
        join();
    }
}

extern(C) int UIAppMain(string[] args)
{
    SIAServerThread siaServer = new SIAServerThread();
    
    if (args.length > 0)
    {
        if (!siaServer.run(args[1]))
            return 0;
    }
    else
    {
        siaServer.run();
    }
    
    int newFileNum = 1;
    
    string settingsPath;
    version(Windows)
    {
        auto appDataDir = environment.get("APPDATA", "./");
        settingsPath = appDataDir ~ "/GeckosEditor";
    }
    version(linux)
    {
        settingsPath = expandTilde("~/GeckosEditor");
    }
    mkdirRecurse(settingsPath);
    auto logFile = File(settingsPath ~ "/app.log", "w");
    Log.setFileLogger(&logFile);
    
    string[] resourceDirs = [
        appendPath(exePath, "res/"),
        appendPath(exePath, "res/i18n/"),
        appendPath(exePath, "res/themes/")
    ];
    Platform.instance.resourceDirs = resourceDirs;
    
    Platform.instance.uiLanguage = "en";
    Platform.instance.uiTheme = "theme_default";
    FontManager.hintingMode = HintingMode.Light;
    FontManager.minAnitialiasedFontSize = 0; // 0 means always antialiased
    FontManager.subpixelRenderingMode = SubpixelRenderingMode.RGB;
    
    // create window
    window = Platform.instance.createWindow("Gecko's Editor v0.0.1", null, WindowFlag.Resizable, 800, 700);
    window.windowIcon = drawableCache.getImage("icon");
     
    VerticalLayout contentLayout = new VerticalLayout();
    
    TabWidget tabs = new TabWidget("TABS");
    tabs.tabClose = delegate(string tabId) {
        tabs.removeTab(tabId);
    };
    
    GTabContent currentContent()
    {
        TabItem tab = tabs.selectedTab;
        if (tab)
        {
            Widget tabBody = tabs.selectedTabBody();
            if (tabBody)
                return cast(GTabContent)tabBody;
            else
                return null;
        }
        else return null;
    }
    
    GESourceEdit currentEditor()
    {
        GTabContent content = currentContent();
        if (content)
            return content.editor;
        else
            return null;
    }
    
    MenuItem mainMenuItems = new MenuItem();
    
    MenuItem fileItem = new MenuItem(new Action(1, "MENU_FILE"c));
    fileItem.add(ACTION_FILE_NEW);
    fileItem.add(ACTION_FILE_OPEN);
    fileItem.add(ACTION_FILE_SAVE);
    fileItem.subitem(2).action.state = ACTION_STATE_DISABLE;
    fileItem.add(ACTION_FILE_SAVE_AS);
    /*
    MenuItem openRecentItem = new MenuItem(new Action(13, "MENU_FILE_OPEN_RECENT", "document-open-recent"));
    openRecentItem.add(new Action(100, "&1: File 1"d));
    openRecentItem.add(new Action(101, "&2: File 2"d));
    openRecentItem.add(new Action(102, "&3: File 3"d));
    openRecentItem.add(new Action(103, "&4: File 4"d));
    openRecentItem.add(new Action(104, "&5: File 5"d));
    fileItem.add(openRecentItem);
    */
    fileItem.add(ACTION_FILE_EXIT);
    mainMenuItems.add(fileItem);

    MenuItem editItem = new MenuItem(new Action(2, "MENU_EDIT"c));
    editItem.add(ACTION_EDIT_COPY);
    editItem.add(ACTION_EDIT_PASTE);
    editItem.add(ACTION_EDIT_CUT);
    editItem.add(ACTION_EDIT_UNDO);
    editItem.add(ACTION_EDIT_REDO);
    editItem.add(ACTION_EDIT_INDENT);
    editItem.add(ACTION_EDIT_UNINDENT);
    editItem.add(ACTION_EDIT_TOGGLE_LINE_COMMENT);
    editItem.add(ACTION_EDIT_TOGGLE_BLOCK_COMMENT);
    editItem.add(ACTION_EDIT_TABS_TO_SPACES);
    editItem.add(ACTION_EDIT_SPACES_TO_TABS);
    editItem.add(ACTION_EDIT_PREFERENCES);
    mainMenuItems.add(editItem);
    
    MenuItem viewItem = new MenuItem(new Action(3, "MENU_VIEW"c));
    MenuItem themeItem = new MenuItem(ACTION_VIEW_THEME);
    themeItem.add(ACTION_VIEW_THEME_DEFAULT);
    themeItem.add(ACTION_VIEW_THEME_DARK);
    auto themeItemDefault = themeItem.subitem(0);
    auto themeItemDark = themeItem.subitem(1);
    themeItemDefault.type = MenuItemType.Radio;
    themeItemDefault.checked = true;
    themeItemDark.type = MenuItemType.Radio;
    themeItemDark.checked = false;
    viewItem.add(themeItem);
    mainMenuItems.add(viewItem);
    
    MenuItem toolsItem = new MenuItem(new Action(4, "MENU_TOOLS"c));
    MenuItem lineEndingsItem = new MenuItem(ACTION_TOOLS_LINE_ENDINGS);
    lineEndingsItem.add(ACTION_TOOLS_LINE_ENDING_LF);
    lineEndingsItem.add(ACTION_TOOLS_LINE_ENDING_CRLF);
    auto lineEndingsLFItem = lineEndingsItem.subitem(0);
    auto lineEndingsCRLFItem = lineEndingsItem.subitem(1);
    lineEndingsLFItem.type = MenuItemType.Radio;
    lineEndingsLFItem.checked = false;
    lineEndingsCRLFItem.type = MenuItemType.Radio;
    lineEndingsCRLFItem.checked = true;
    toolsItem.add(lineEndingsItem);
    mainMenuItems.add(toolsItem);
    
    MenuItem windowItem = new MenuItem(new Action(5, "MENU_WINDOW"c));
    windowItem.add(ACTION_WINDOW_MINIMIZE);
    windowItem.add(ACTION_WINDOW_MAXIMIZE);
    windowItem.add(ACTION_WINDOW_RESTORE);
    mainMenuItems.add(windowItem);
    
    MenuItem helpItem = new MenuItem(new Action(6, "MENU_HELP"c));
    helpItem.add(ACTION_HELP_VIEW_HELP);
    helpItem.add(ACTION_HELP_ABOUT);
    mainMenuItems.add(helpItem);
    
    MainMenu mainMenu = new MainMenu(mainMenuItems);
    
    mainMenu.menuItemClick = delegate(MenuItem item) {
        const Action a = item.action;
        if (a) {
            return contentLayout.dispatchAction(a);
        }
        return false;
    };
    contentLayout.addChild(mainMenu);
    contentLayout.keyToAction = delegate(Widget source, uint keyCode, uint flags) {
        return mainMenu.findKeyAction(keyCode, flags);
    };
    
    contentLayout.onAction = delegate(Widget source, const Action a)
    {
        if (a.id == ACTION_VIEW_THEME_DEFAULT)
        {
            Platform.instance.uiTheme = "theme_default";
            return true;
        }
        else if (a.id == ACTION_VIEW_THEME_DARK)
        {
            Platform.instance.uiTheme = "theme_dark";
            return true;
        }
        else if (a.id == ACTION_FILE_NEW)
        {
            TabItem tab = tabs.selectedTab;
            
            FileDialog dlg = new FileDialog(UIString.fromRaw("Save Text File"d), window, null,
                DialogFlag.Modal | DialogFlag.Resizable | FileDialogFlag.FileMustExist | FileDialogFlag.Save);
            dlg.minWidth = 800;
            dlg.minHeight = 320;
            dlg.allowMultipleFiles = false;
            dlg.filename = "New file.txt";
            dlg.dialogResult = delegate(Dialog dlg, const Action result)
            {
                if (result.id == ACTION_SAVE.id)
                {
                    string filename = (cast(FileDialog)dlg).filename;
                    auto content = newFile(tabs, filename);
                    if (content)
                    {
                        auto editor = content.editor;
                        editor.content.save(filename, TextFileFormat(EncodingType.UTF8, editor.lineEnding, false));
                    }
                }
            };
            
            dlg.show();
            
            return true;
        }
        else if (a.id == ACTION_FILE_OPEN)
        {
            FileDialog dlg = new FileDialog(UIString.fromRaw("Open Text File"d), window, null,
                DialogFlag.Modal | DialogFlag.Resizable | FileDialogFlag.Open);
            dlg.minWidth = 800;
            dlg.minHeight = 320;
            dlg.allowMultipleFiles = true;
            dlg.addFilter(FileFilterEntry(UIString("FILTER_ALL_FILES", "All files (*)"d), "*"));
            dlg.addFilter(FileFilterEntry(UIString("FILTER_TEXT_FILES", "Text files (*.txt)"d), "*.txt"));
            dlg.filterIndex = 0;
            dlg.dialogResult = delegate(Dialog dlg, const Action result)
            {
                if (result.id == ACTION_OPEN.id)
                {
                    string[] filenames = (cast(FileDialog)dlg).filenames;
                    foreach (filename; filenames)
                    {
                        auto content = openFile(tabs, filename);
                        if (content is null)
                        {
                            window.showMessageBox(
                                UIString.fromRaw("File open error"d),
                                UIString.fromRaw("Cannot open file "d ~ toUTF32(filename)));
                        }
                    }
                }
            };
            
            dlg.show();
            return true;
        }
        else if (a.id == ACTION_FILE_SAVE)
        {
            TabItem tab = tabs.selectedTab;
            if (tab)
            {
                auto content = currentContent();
                auto editor = currentEditor();
                if (content && editor)
                {
                    string filename = content.filename;
                    editor.content.save(filename, TextFileFormat(EncodingType.UTF8, editor.lineEnding, false));
                    return true;
                }
            }
        }
        else if (a.id == ACTION_FILE_SAVE_AS)
        {
            TabItem tab = tabs.selectedTab;
            if (tab)
            {
                auto content = currentContent();
                auto editor = currentEditor();
                if (content && editor)
                {
                    FileDialog dlg = new FileDialog(UIString.fromRaw("Save Text File"d), window, null,
                        DialogFlag.Modal | DialogFlag.Resizable | FileDialogFlag.FileMustExist | FileDialogFlag.Save);
                    dlg.minWidth = 800;
                    dlg.minHeight = 320;
                    dlg.allowMultipleFiles = false;
                    dlg.filename = content.filename;
                    dlg.dialogResult = delegate(Dialog dlg, const Action result)
                    {
                        if (result.id == ACTION_SAVE.id)
                        {
                            string filename = (cast(FileDialog)dlg).filename;
                            editor.content.save(filename, TextFileFormat(EncodingType.UTF8, editor.lineEnding, false));
                            
                            int index = tabs.tabIndex(filename);
                            if (index >= 0)
                            {
                                // File is already opened in another tab, close it
                                tabs.removeTab(filename);
                            }
                            
                            // Rename tab
                            int oldindex = tabs.tabIndex(tab.id);
                            if (oldindex >= 0)
                            {
                                string tabName = filename.baseName;
                                tabs.renameTab(oldindex, UIString.fromRaw(tabName));
                            }
                        }
                    };
                    
                    dlg.show();
                }
            }
            
            return true;
        }
        else if (a.id == ACTION_FILE_EXIT)
        {
            window.close();
            return true;
        }
        else if (a.id == ACTION_EDIT_TABS_TO_SPACES)
        {
            auto editor = currentEditor();
            auto c = editor.content;
            int numSpaces = editor.tabSize;
            dstring spaces = " "d.replicate(numSpaces);
            dstring[] newLines = c.text.replace("\t"d, spaces).splitLines;
            TextRange range = TextRange(c.lineBegin(0), c.endOfFile);
            EditOperation op = new EditOperation(EditAction.Replace, range, newLines);
            c.performOperation(op, editor);
            editor.detectIndentation();
            return true;
        }
        else if (a.id == ACTION_EDIT_SPACES_TO_TABS)
        {
            auto editor = currentEditor();
            auto c = editor.content;
            int numSpaces = editor.tabSize;
            dstring spaces = " "d.replicate(numSpaces);
            dstring[] newLines = c.text.replace(spaces, "\t"d).splitLines;
            TextRange range = TextRange(c.lineBegin(0), c.endOfFile);
            EditOperation op = new EditOperation(EditAction.Replace, range, newLines);
            c.performOperation(op, editor);
            editor.detectIndentation();
            return true;
        }
        else if (a.id == ACTION_TOOLS_LINE_ENDING_LF)
        {
            auto editor = currentEditor();
            if (editor.lineEnding != LineEnding.LF)
            {
                editor.lineEnding = LineEnding.LF;
                
            }
            return true;
        }
        else if (a.id == ACTION_TOOLS_LINE_ENDING_CRLF)
        {
            auto editor = currentEditor();
            if (editor.lineEnding != LineEnding.CRLF)
            {
                editor.lineEnding = LineEnding.CRLF;
            }
            return true;
        }
        else if (a.id == ACTION_WINDOW_MINIMIZE)
        {
            window.minimizeWindow();
            return true;
        }
        else if (a.id == ACTION_WINDOW_MAXIMIZE)
        {
            window.maximizeWindow();
            return true;
        }
        else if (a.id == ACTION_WINDOW_RESTORE)
        {
            window.restoreWindow();
            return true;
        }
        else if (a.id == ACTION_HELP_VIEW_HELP)
        {
            // TODO: show help.chm
            return true;
        }
        else if (a.id == ACTION_HELP_ABOUT)
        {
            window.showMessageBox(UIString.fromRaw("About"d), UIString.fromRaw("Gecko's Editor v0.0.1"d));
            return true;
        }
        else if (a.id == ACTION_SERVER_OPEN)
        {
            string filename = a.stringParam;
            auto content = openFile(tabs, filename);
            window.restoreWindow();
            if (content is null)
            {
                window.showMessageBox(
                    UIString.fromRaw("File open error"d),
                    UIString.fromRaw("Cannot open file "d ~ toUTF32(filename)));
            }
            return true;
        }
        //else
        //return contentLayout.dispatchAction(a);
        return false;
    };
    
    // Setup tab view
    tabs.tabChanged = delegate(string newTabId, string oldTabId)
    {
        window.windowCaption = tabs.tab(newTabId).text.value ~ " - Gecko's Editor"d;
    };
    tabs.layoutWidth(FILL_PARENT).layoutHeight(FILL_PARENT);
    
    if (args.length > 1)
    {
        string filename = args[1];
        if (tabs.openFile(filename))
        {
            //
        }
        else window.showMessageBox(
            UIString.fromRaw("File open error"d),
            UIString.fromRaw("Cannot open file "d ~ toUTF32(filename)));
    }
    
    contentLayout.addChild(tabs);
    
    contentLayout.layoutHeight(FILL_PARENT).layoutWidth(FILL_PARENT);
    
    window.mainWidget = contentLayout;

    // show window
    window.show();
    window.setWindowState(WindowState.maximized, true);

    // run message loop
    int returnCode = Platform.instance.enterMessageLoop();
    siaServer.close();
    return returnCode;
}
