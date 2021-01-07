//
//  NoteDetail.swift
//  VoCap
//
//  Created by 윤태민 on 12/9/20.
//

import SwiftUI

struct NoteDetail: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var note: Note          // @State할 때는, 값이 바뀌어도 갱신이 안 됨,
    
    @State var order: Int = -1
    @State var term: String = ""
    @State var definition: String = ""
    @State var isMemorized: Bool = false
    
    @State var tmpNoteDetails: [TmpNoteDetail] = []
    
    @State private var isEditMode: EditMode = .inactive
    
    @State private var isTermsHiding: Bool = false
    @State private var isDefsHiding: Bool = false
    @State private var isShuffled: Bool = false
    
    var body: some View {
        List {
            ForEach(tmpNoteDetails) { noteDetail in
                HStack {
                    ZStack {
                        Text(noteDetail.term)
                            .modifier(NoteDetailListModifier())
                        if isTermsHiding == true {
                            Button(action: { print(noteDetail.id) }) {
                                Rectangle()
                                    .frame(maxWidth: .infinity, maxHeight: 60)
                                    .padding(-5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                        
                    ZStack {
                        Text(noteDetail.definition)
                            .modifier(NoteDetailListModifier())
                        if isDefsHiding == true {
                            Button(action: { print(noteDetail.id) }) {
                                Rectangle()
                                    .frame(maxWidth: .infinity, maxHeight: 60)
                                    .padding(-5)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    Button(action: {
                        if isEditMode == .inactive  { changeMemorizedState(index: noteDetail.order) }
                        else                        { editNoteDetail(index: noteDetail.order) }
                    }) {
                        noteDetail.isMemorized == true ? Image(systemName: "square.fill") : Image(systemName: "square")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .listRowInsets(EdgeInsets())
                .padding(5)
            }
            .onDelete(perform: deleteItems)
        }
        .onAppear() { copyNoteDetails() }
        .navigationBarTitle("\(note.title!)", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { EditButton().disabled(isShuffled) }
            
            ToolbarItem(placement: .bottomBar) { showingTermsButton }
            ToolbarItem(placement: .bottomBar) { Spacer() }
            ToolbarItem(placement: .bottomBar) { shuffleButton }
            ToolbarItem(placement: .bottomBar) { Spacer() }
            ToolbarItem(placement: .bottomBar) { showingDefsButton }
        }
        .environment(\.editMode, self.$isEditMode)          // 해당 위치에 없으면 isEditMode 안 먹힘
        
        HStack {
            TextField("term", text: $term)
                .modifier(NoteDetailEditorModifier())
            
            TextField("definition", text: $definition)
                .modifier(NoteDetailEditorModifier())
            
            Button(action: { add() }) {
                Text("Add")
            }
            .disabled(term == "" || definition == "" ? true : false)
        }
        .padding()
    }
}

// MARK: - Tool Bar Items
extension NoteDetail {
    var showingTermsButton: some View {
        Button(action: { isTermsHiding.toggle() }) {
            isTermsHiding == true ? Image(systemName: "arrow.left") : Image(systemName: "arrow.right")
        }
    }
    
    var shuffleButton: some View {
        Button(action: { shuffleButtonAction() }) {
            isShuffled == true ? Image(systemName: "return") : Image(systemName: "shuffle")
        }
    }
    
    var showingDefsButton: some View {
        Button(action: { isDefsHiding.toggle() }) {
            isDefsHiding == true ? Image(systemName: "arrow.right") : Image(systemName: "arrow.left")
        }
    }
}


// MARK: - Other Functions
private extension NoteDetail {
    func copyNoteDetails() {
        for i in 0..<note.term.count {
            tmpNoteDetails.append(TmpNoteDetail(id: i, order: i, term: note.term[i], definition: note.definition[i], isMemorized: note.isMemorized[i]))
        }
    }
    
    func shuffleButtonAction() -> Void {
        isShuffled.toggle()
        if isShuffled == true {
            tmpNoteDetails.shuffle()
            for i in 0..<note.term.count {
                tmpNoteDetails[i].order = i
            }
        }
        else {
            tmpNoteDetails.removeAll()
            copyNoteDetails()
        }
    }
}


// MARK: - Modify NoteDetails
extension NoteDetail {
    func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    func add() {
        if isEditMode == .inactive {
            note.term.append(term)
            note.definition.append(definition)
            note.isMemorized.append(false)
            
            order = note.term.count - 1
            tmpNoteDetails.append(TmpNoteDetail(id: order, order: order, term: term, definition: definition, isMemorized: isMemorized))
            note.totalNumber = Int16(order + 1)
            saveContext()
        }
        else {
            note.term[order] = term
            note.definition[order] = definition
            
            tmpNoteDetails[order] = TmpNoteDetail(id: order, order: order, term: term, definition: definition, isMemorized: isMemorized)
            saveContext()
        }
        term = ""
        definition = ""
    }
    
    func deleteItems(at offsets: IndexSet) {
        note.totalNumber -= 1
        if tmpNoteDetails[offsets.map({$0}).first!].isMemorized == true {
            note.memorizedNumber -= 1
        }

        note.term.remove(atOffsets: offsets)
        note.definition.remove(atOffsets: offsets)
        note.isMemorized.remove(atOffsets: offsets)
        
        tmpNoteDetails.remove(atOffsets: offsets)
        saveContext()
        
        for i in 0..<note.term.count {
            tmpNoteDetails[i].id = i
            tmpNoteDetails[i].order = i
        }
    }
    
    func changeMemorizedState(index: Int) {
        if tmpNoteDetails[index].isMemorized == true {
            tmpNoteDetails[index].isMemorized = false
            note.memorizedNumber -= 1
        }
        else {
            tmpNoteDetails[index].isMemorized = true
            note.memorizedNumber += 1
        }
        
        note.isMemorized[tmpNoteDetails[index].id] = tmpNoteDetails[index].isMemorized
        saveContext()
    }
    
    func editNoteDetail(index: Int) {
        term = tmpNoteDetails[index].term
        definition = tmpNoteDetails[index].definition
    }
}


//struct NoteDetail_Previews: PreviewProvider {
//
//    static var previews: some View {
//        NoteDetail(note: Note())
//            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
//            .previewDevice("iPhone XR")
//    }
//}




