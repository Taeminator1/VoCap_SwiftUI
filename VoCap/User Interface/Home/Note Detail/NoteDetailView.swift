//
//  NoteDetailView.swift
//  VoCap
//
//  Created by 윤태민 on 12/9/20.
//

import SwiftUI
import GoogleMobileAds



struct NoteDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var note: Note          // @State할 때는, 값이 바뀌어도 갱신이 안 됨,
    
    @State var tmpNoteDetails: [NoteDetail] = []
    
    @State var editMode: EditMode = .inactive
    @State var selection = Set<UUID>()
    
    @State var itemControl = ItemControl()
    @State var isScaledArray: [Bool] = []
    
    @State var isTextField: Bool = false
    @State var isEditButton : Bool = true
    @State var isAddButton: Bool = true
    @State var showingAddItemAlert: Bool = false
    
    @State var scrollTarget: Int?
    
    @State var selectedRow = -1
    @State var selectedCol = -1
    @State var closeKeyboard: Bool = true
    
    @State var listFrame: CGFloat = 0.0
    
//    let limitedNumberOfItems: Int = 500
    
    @Binding var isDisableds: [Bool]
    
    @State var orientation = UIDevice.current.orientation
    let orientationChanged = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .makeConnectable()
            .autoconnect()
    
    let alertController = UIAlertController(title: "Alert", message: "Please enter text", preferredStyle: .alert)
    
    var body: some View {
        VStack {
            GADBannerViewController()
                .frame(width: kGADAdSizeBanner.size.width, height: kGADAdSizeBanner.size.height)        // Frame 사이즈 변경 가능(실제 앱 구동하는 것 보고 변경 여부 결정)
            
            GeometryReader { geometry in
                ScrollViewReader { proxy in
//                    List(selection: $selection) {
                    List {
                        ForEach(tmpNoteDetails) { noteDetail in
                            noteDetailRow(noteDetail)
                        }
                        .onDelete(perform: deleteItem)
                        .deleteDisabled(itemControl.isShuffled || editMode == .active)             // Shuffle 상태일 때 delete 못하게 함
                    }
                    .animation(.default)
                    .alert(isPresented: $showingAddItemAlert, TextAlert(title: "Add Item".localized, message: "Enter a term and a definition to memorize. ".localized, action: { term, definition  in
                        if let term = term, let definition = definition {
//                            if (term != "" || definition != "") && note.term.count < limitedNumberOfItems {
                                addItem(term, definition)

                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {         // 딜레이 안 주면 추가한 목록이 안 보임
                                    scrollTarget = note.term.count - 1
                                }
                                showingAddItemAlert = true
//                            }
                        }
                    }))
    //                .frame(height: listFrame)
                    .onChange(of: scrollTarget) { target in
                        if let target = target {
                            scrollTarget = nil
    //                        withAnimation { proxy.scrollTo(tmpNoteDetails[target].id, anchor: .bottom) }
                            withAnimation { proxy.scrollTo(tmpNoteDetails[target].id) }
                        }
                    }
                    .onAppear() {
                        UITableView.appearance().showsVerticalScrollIndicator = false
                        
                        copyNoteDetails()
                        listFrame = geometry.size.height > geometry.size.width ? geometry.size.height : geometry.size.width             // 없으면 .bottomBar 없어짐...
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            withAnimation {
                                isDisableds[0].toggle()
                            }
                        }
                    }
                    .onDisappear() {
                        for i in 0..<isDisableds.count {
                            isDisableds[i] = false
                        }
                    }
                    .navigationBarTitle("\(note.title!)", displayMode: .inline)
                    .toolbar {
                        // NavigationBar
                        menuButton
                        
                        // BottomBar
                        showingTermsButton
                        spacer
                        shuffleButton
                        spacer
                        showingDefsButton
                    }
                    .environment(\.editMode, self.$editMode)          // 해당 위치에 없으면 editMode 안 먹힘
                }
            }
            .accentColor(.mainColor)
        }
        .onReceive(orientationChanged) { _ in                   // XxTextAlert을 추가하면 rotate 시, .bottom Toolbar가 사라져 방지하기 위함
            self.orientation = UIDevice.current.orientation
//            print(orientation.isLandscape)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {         // 딜레이 안 주면 연속해서 Rotate했을 때, .bottom Toolbar 사라지는 문제 재발
                isDisableds[0].toggle()
            }
        }
    }
}

// MARK: - Menu
extension NoteDetailView {
    var addItemButton: some View {
        Button(action: {
            showingAddItemAlert = true
        }) {
            Label("Add Item", systemImage: "plus")
        }
    }
  
    var editItemButton: some View {
        Button(action: {
            itemControl = ItemControl()
            
            selectedRow = -1
            selectedCol = -1
            closeKeyboard = false
            
            if itemControl.isShuffled { shuffle() }
            
            editMode = .active
            selection = Set<UUID>()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {            // for animation
                isTextField = true
                isEditButton = true
            }
        }) {
            Label("Edit item", systemImage: "pencil")
        }
    }
    
    var doneButton: some View {
        Button(action: {
            isEditButton = false
            isTextField = false
            
            editMode = .inactive
            selection = Set<UUID>()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {            // 없으면 Keyboard 뒤 배경 안 사라짐
                closeKeyboard = true
                isEditButton = true
            }
            
            saveContext()
            
            for i in 0..<note.term.count {
                tmpNoteDetails[i].term = note.term[i]
                tmpNoteDetails[i].definition = note.definition[i]
            }
            
        }) {
            Text("Done")
        }
    }
    
    var hideMemorizedButton: some View {
        Button(action: { itemControl.hideMemorized.toggle() }) {
            itemControl.hideMemorized == true ? Label("Show Memorized", systemImage: "eye") : Label("Hide Memorized", systemImage: "eye.slash")
        }
    }
    
    func addItem(_ term: String, _ definitino: String) {
        note.term.append(term)
        note.definition.append(definitino)
        note.isMemorized.append(false)
        
        let index = note.term.count - 1
        tmpNoteDetails.append(NoteDetail(order: index, term: note.term[index], definition: note.definition[index]))
        saveContext()
    
        isScaledArray.append(false)
    }
}

extension NoteDetailView {
    @ViewBuilder        // 없으면 Function declares an opaque return type ... error 발생
    func noteDetailRow(_ noteDetail: NoteDetail) -> some View {
        if noteDetail.isMemorized && itemControl.hideMemorized {
            EmptyView()
        }
        else {
            HStack {
                ForEach(0 ..< 2) { col in
                    noteDetailCell(noteDetail, col)
                        .onTapGesture {
                            selectedRow = noteDetail.order
                            selectedCol = col           // 여기 있으면 Keyboard 뒤에 View가 안 없어지는 경우 생김
                            if isTextField { scrollTarget = noteDetail.order }
                        }
                }
                
                Button(action: {
                    if editMode == .active {
                        CustomUITextField(selectedRow: $selectedRow, selectedCol: $selectedCol, closeKeyboard: $closeKeyboard).done(button: UIBarButtonItem())
                        scrollTarget = noteDetail.order
                    }
                    changeMemorizedState(id: noteDetail.id)
                    closeKeyboard = true            // 없으면 키보드 잔상 남음
                }) {
                    noteDetail.isMemorized == true ? Image(systemName: "checkmark.square.fill").imageScale(.large) : Image(systemName: "square").imageScale(.large)
                }
                .buttonStyle(PlainButtonStyle())        // TextField 상태일 때, 경계부분 누르면 버튼이 눌리는 현상 막기 위해
            }
            .padding()
            .modifier(ListModifier(verticalPadding: -5))
        }
    }
    
    func noteDetailCell(_ noteDetail: NoteDetail, _ selectedCol: Int) -> some View {
        return ZStack {
            switch selectedCol {
            case 0:
                if isTextField == false {
                    noteDetailText(noteDetail.term, bodyColor: .textBodyColor, strokeColor: .tTextStrokeColor)
                    GeometryReader { geometry in
                        HStack {
                            noteDetailScreen(noteDetail.order, finalWidth: geometry.size.width, screenColor: .tScreenColor, isScreen: itemControl.screen.left, anchor: .leading)
                            Spacer()
                        }
                    }
                }
                else {
                    NoteDetailTextField("Term", $note.term[noteDetail.order], noteDetail.order, 0, bodyColor: .textFieldBodyColor, strokeColor: .tTextFieldStrokeColor)
                }
            case 1:
                if isTextField == false {
                    noteDetailText(noteDetail.definition, bodyColor: .textBodyColor, strokeColor: .dTextStrokeColor)
                    GeometryReader { geometry in
                        HStack {
                            Spacer()
                            noteDetailScreen(noteDetail.order, finalWidth: geometry.size.width, screenColor: .dScreenColor, isScreen: itemControl.screen.right, anchor: .trailing)     // 여기는 + 1 안함
                        }
                    }
                }
                else {
                    NoteDetailTextField("Definition", $note.definition[noteDetail.order], noteDetail.order, 1, bodyColor: .textFieldBodyColor, strokeColor: .dTextFieldStrokeColor)
                }
                
            default:
                Text("Error")
            }
        }
    }
}

extension NoteDetailView {
    func noteDetailText(_ text: String, bodyColor: Color, strokeColor: Color) -> some View {
        Text(text)
            .font(.body)
            .minimumScaleFactor(0.8)
            .lineLimit(2)
            .padding(.horizontal)
            .modifier(NoteDetailListModifier(bodyColor: bodyColor, strokeColor: strokeColor))
    }
    
    func NoteDetailTextField(_ title: String, _ text: Binding<String>, _ row: Int, _ col: Int, bodyColor: Color, strokeColor: Color) -> some View {

        var responder: Bool {
            return row == selectedRow && col == selectedCol
        }
        
        return CustomTextFieldWithToolbar(title: title, text: text, selectedRow: $selectedRow, selectedCol: $selectedCol, isEnabled: $isTextField, closeKeyboard: $closeKeyboard, col: col, isFirstResponder: responder)
            .padding(.horizontal)
            .modifier(NoteDetailListModifier(bodyColor: bodyColor, strokeColor: strokeColor, lineWidth: 1.0))
    }
    
    func noteDetailScreen(_ order: Int, initWidth: CGFloat = 4.0, finalWidth: CGFloat, screenColor: Color, isScreen: Bool, anchor: UnitPoint) -> some View {
        Rectangle()
            .foregroundColor(screenColor)
            .frame(width: initWidth)
            .scaleEffect(x: isScreen && !isScaledArray[order] ? finalWidth / initWidth : 1.0, y: 1.0, anchor: anchor)
            .onTapGesture{}                 // Scroll 되게 하려면 필요(해당 자리에)
            .modifier(CustomGestureModifier(isPressed: $isScaledArray[order], f: { }))
    }
}

// MARK: - Tool Bar Items
extension NoteDetailView {
    var menuButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if editMode == .inactive {
                Menu {
                    addItemButton.disabled(isAddButton == false)
                    editItemButton.disabled(isEditButton == false)
                    hideMemorizedButton
                }
                label: { Label("", systemImage: "ellipsis.circle").imageScale(.large) }
            }
            else {
                doneButton
            }
        }
    }
    
    var spacer: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) { Spacer() }
    }
    
    var showingTermsButton: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button(action: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        isDisableds[1].toggle()
                    }
                }
                
                itemControl.toggleLeft()
                
            }) {
                if editMode == .inactive {
                    itemControl.screen.left == true ? Image("arrow.right.on").imageScale(.large) : Image("arrow.right.off").imageScale(.large)
                }
            }
        }
    }
    
    var shuffleButton: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button(action: { shuffle() }) {
                if editMode == .inactive {
                    itemControl.isShuffled == true ? Image("shuffle.on").imageScale(.large) : Image("shuffle.off").imageScale(.large)
                }
            }
        }
    }
    
    var showingDefsButton: some ToolbarContent {
        ToolbarItem(placement: .bottomBar) {
            Button(action: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        isDisableds[1].toggle()
                    }
                }
                
                itemControl.toggleRight()
                
            }) {
                if editMode == .inactive {
                    itemControl.screen.right == true ? Image("arrow.left.on").imageScale(.large) : Image("arrow.left.off").imageScale(.large)
                }
            }
        }
    }
}


// MARK: - Other Functions
extension NoteDetailView {
    func copyNoteDetails() {
        tmpNoteDetails = [NoteDetail]()
        
        for i in 0..<note.term.count {
            tmpNoteDetails.append(NoteDetail(order: i, term: note.term[i], definition: note.definition[i], isMemorized: note.isMemorized[i]))
            
            isScaledArray.append(false)
        }
    }
    
    func shuffle() -> Void {
        itemControl.isShuffled.toggle()
        
        if itemControl.isShuffled == true {
            tmpNoteDetails.shuffle()
        }
        else {
            tmpNoteDetails = tmpNoteDetails.sorted(by: { $0.order < $1.order })
        }
    }
}


// MARK: - Modify NoteDetails
extension NoteDetailView {
    func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    var deleteMemorizedButton: some View {      // TextField를 없애면 에러 발생
        Button(action: {
            if editMode != .inactive {
                isEditButton = false
                isTextField = false
                
                editMode = .inactive
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {            // 없으면 Keyboard 뒤 배경 안 사라짐
                
                for i in 0..<note.term.count {
                    if note.isMemorized[i] == true {
                        selection.insert(tmpNoteDetails[i].id)
                    }
                }
                
                for id in selection {
                    if let index = tmpNoteDetails.lastIndex(where: { $0.id == id })  {
                        note.term.remove(at: index)
                        note.definition.remove(at: index)
                        note.isMemorized.remove(at: index)
                        
                        tmpNoteDetails.remove(at: index)
                        isScaledArray.remove(at: index)
                    }
                }
                saveContext()
                
                for i in 0..<note.term.count { tmpNoteDetails[i].order = i }
                
                selection = Set<UUID>()
                
                isEditButton = true
            }
        }) {
            Text("Delete Memorized")
        }
    }
    
    func deleteItem(at offsets: IndexSet) {         // edit 상태에서 마지막꺼 지우면 에러 발생
        note.term.remove(atOffsets: offsets)
        note.definition.remove(atOffsets: offsets)
        note.isMemorized.remove(atOffsets: offsets)

        tmpNoteDetails.remove(atOffsets: offsets)
        isScaledArray.remove(atOffsets: offsets)
        
        saveContext()
        
        // shuffle 상태에서 삭제하면 해당 구문이 return 못하게 함(shuffle 상태에서는 delete 못하게 함)
        for i in 0..<note.term.count {
            tmpNoteDetails[i].order = i
        }
    }
    
    func changeMemorizedState(id: UUID) {
        if let index = tmpNoteDetails.firstIndex(where: { $0.id == id }) {
            tmpNoteDetails[index].isMemorized.toggle()
            
            note.isMemorized[tmpNoteDetails[index].order] = tmpNoteDetails[index].isMemorized
            saveContext()
        }
    }
}


//struct NoteDetailView_Previews: PreviewProvider {
//
//    static var previews: some View {
//        NoteDetailView(note: Note())
//            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//            .previewDevice("iPhone XR")
//    }
//}

