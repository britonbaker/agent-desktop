import AppKit
final class FlippedDocument:NSView {override var isFlipped:Bool {true}}

final class Fixture:NSObject,NSApplicationDelegate {
    var window:NSWindow!
    let draft=NSTextField(string:"")
    let search=NSTextField(string:"")
    let scroll=NSScrollView()
    let status=NSTextField(labelWithString:"Test item present")
    let details=NSTextField(labelWithString:"Details closed")
    var deleted=0,timer:Timer?,last=Data()
    let output=CommandLine.arguments.dropFirst().first ?? "/tmp/rove-action-fixture-state.json"
    func applicationDidFinishLaunching(_ note:Notification) {
        window=NSWindow(contentRect:NSRect(x:300,y:220,width:500,height:500),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title="Rove action test fixture"
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=14
        stack.frame=NSRect(x:25,y:25,width:450,height:450)
        stack.addArrangedSubview(NSTextField(labelWithString:"Disposable local controls. No real files are deleted."))
        draft.placeholderString="Draft";draft.setAccessibilityLabel("Draft");draft.identifier=NSUserInterfaceItemIdentifier("draft")
        draft.widthAnchor.constraint(equalToConstant:360).isActive=true;stack.addArrangedSubview(draft)
        search.placeholderString="Search";search.setAccessibilityLabel("Search")
        search.widthAnchor.constraint(equalToConstant:360).isActive=true;stack.addArrangedSubview(search)
        scroll.setAccessibilityLabel("Test list");scroll.hasVerticalScroller=true
        scroll.widthAnchor.constraint(equalToConstant:360).isActive=true;scroll.heightAnchor.constraint(equalToConstant:110).isActive=true
        let document=FlippedDocument(frame:NSRect(x:0,y:0,width:340,height:1200))
        for index in 0..<40 {let row=NSTextField(labelWithString:"Row \(index+1)");row.frame=NSRect(x:10,y:index*30,width:250,height:22);document.addSubview(row)}
        scroll.documentView=document;stack.addArrangedSubview(scroll)
        stack.addArrangedSubview(NSButton(title:"Open details",target:self,action:#selector(openDetails)))
        stack.addArrangedSubview(details)
        stack.addArrangedSubview(NSButton(title:"Delete test item",target:self,action:#selector(deleteItem)))
        stack.addArrangedSubview(NSButton(title:"Change selection",target:self,action:#selector(changeSelection)))
        stack.addArrangedSubview(status)
        window.contentView?.addSubview(stack);window.initialFirstResponder=draft;window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        timer=Timer.scheduledTimer(withTimeInterval:0.05,repeats:true) {[weak self] _ in self?.save()};save()
    }
    @objc func openDetails() {details.stringValue="Details open";save()}
    @objc func deleteItem() {deleted+=1;status.stringValue="Test item deleted";save()}
    @objc func changeSelection() {status.stringValue="Different test item selected";save()}
    func save() {
        guard output.hasPrefix("/tmp/") || output.hasPrefix(FileManager.default.temporaryDirectory.path) else {return}
        let focused=draft.currentEditor() != nil ? "Draft" : search.currentEditor() != nil ? "Search" : "other"
        let data=(try? JSONSerialization.data(withJSONObject:["draft":draft.stringValue,"details":details.stringValue,"deleted":deleted,"focused":focused,"scroll":scroll.documentVisibleRect.minY],options:.sortedKeys)) ?? Data()
        if data != last {try? data.write(to:URL(fileURLWithPath:output),options:.atomic);last=data}
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ app:NSApplication)->Bool {true}
}
let app=NSApplication.shared
let delegate=Fixture();app.delegate=delegate;app.setActivationPolicy(.regular);app.run()
