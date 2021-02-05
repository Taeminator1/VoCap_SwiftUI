//
//  XxCustomTextField.swift
//  VoCap
//
//  Created by 윤태민 on 1/31/21.
//

//  숫자를 입력하면 자동으로 다음 TextField로 넘어감
//  https://www.hackingwithswift.com/forums/100-days-of-swiftui/jump-focus-between-a-series-of-textfields-pin-code-style-entry-widget/765
//  TextField간 전환 가능하도록 버튼 추가(기존에는 한 번 전환되면 다시 돌아가지 못함_주석 부분)

//  close 버튼을 누르면 keyboard가 사라짐
//  https://gist.github.com/wilsoncusack/6e80af92cf86bfae768bda7c64009789

//  Keyboard 위에 버튼 추가
//  https://stackoverflow.com/questions/59003612/extend-swiftui-keyboard-with-custom-button

import SwiftUI

struct SwiftUIView: View {
    @State private var xxNumberOfCells: Int = 2
    @State private var xxSelectedCell = -1
    
    @State private var yyNumberOfCells: Int = 2
    @State private var yySelectedCell = -1
    
    @State var text1: String = ""
    @State var text2: String = ""
    
    var body: some View {
        VStack {
            HStack {
                ForEach(0 ..< self.xxNumberOfCells) { index in
                    XxTextInputCell(numberOfCells: self.$xxNumberOfCells, selectedCell: self.$xxSelectedCell, isEnabled: .constant(false), index: index)
                        .onTapGesture {
                            xxSelectedCell = index
                        }
                        .padding(.horizontal)
                        .modifier(NoteDetailListModifier(strokeColor: .blue))
                }
            }
            
            HStack {
                ForEach(0 ..< self.yyNumberOfCells) { index in
                    Text("dd")
                    XxTextInputCell(numberOfCells: self.$xxNumberOfCells, selectedCell: self.$xxSelectedCell, isEnabled: .constant(false), index: index)
                        .onTapGesture {
                            yySelectedCell = index
                        }
                        .padding(.horizontal)
                        .modifier(NoteDetailListModifier(strokeColor: .blue))
                }
            }
            
            HStack {
                TextField("placeholder", text: $text1)
                    .autocapitalization(.none)
                    .padding(.horizontal)
                    .modifier(NoteDetailListModifier(strokeColor: .blue))
                
                TextField("placeholder", text: $text2)
                    .autocapitalization(.none)
                    .padding(.horizontal)
                    .modifier(NoteDetailListModifier(strokeColor: .green))
            }
        }
        .padding()
    }
}

// MARK: - Preivew
struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIView()
            .previewDevice("iPhone XR")
//            .previewDevice("iPhone SE (2nd generation)")
//            .preferredColorScheme(.dark)
    }
}


struct XxTextInputCell: View {
    @State private var textValue: String = ""
    @Binding var numberOfCells: Int
    @Binding var selectedCell: Int
    @Binding var isEnabled: Bool

    var index: Int
    var responder: Bool {
        return index == selectedCell
    }

    var body: some View {
        XxCustomTextField(title: "placeholder", text: $textValue, numberOfCells: $numberOfCells, selectedCell: $selectedCell, keyType: UIKeyboardType.default, isEnabled: $isEnabled, isFirstResponder: responder)
//            .frame(height: 10)
//            .frame(maxWidth: .infinity, alignment: .center)
//            .padding([.trailing, .leading], 10)
//            .padding([.vertical], 15)
//            .overlay(
//                RoundedRectangle(cornerRadius: 6)
//                    .stroke(Color.red.opacity(0.5), lineWidth: 2)
//            )
    }
}


struct XxCustomTextField: UIViewRepresentable {
    
    class Coordinator: NSObject, UITextFieldDelegate {

        @Binding var text: String
        @Binding var selectedCell: Int

        init(text: Binding<String>, selectedCell: Binding<Int>) {
            _text = text
            _selectedCell = selectedCell
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            DispatchQueue.main.async {
                self.text = textField.text ?? ""
            }
        }
    }

    var title: String = ""              // Placeholder
    @Binding var text: String
    @Binding var numberOfCells: Int
    @Binding var selectedCell: Int
    var keyType: UIKeyboardType = .default
    @Binding var isEnabled: Bool
    
    var isFirstResponder: Bool = false

    func makeUIView(context: UIViewRepresentableContext<XxCustomTextField>) -> UITextField {
        let textField = XxCustomUITextField(numberOfCells: $numberOfCells, selectedCell: $selectedCell)
        textField.placeholder = title
        textField.delegate = context.coordinator
        textField.textAlignment = .center
        textField.keyboardType = keyType
        textField.autocapitalizationType = .none
        textField.textAlignment = .left
        textField.isUserInteractionEnabled = isEnabled
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let toolBar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: 44))
        
        let moveLeftButton = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(textField.moveLeft))
        
        let space = UIBarButtonItem(title: " ")
        
        let moveRightButton = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), style: .plain, target: self, action: #selector(textField.moveRight(button:)))
        
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(textField.done(button:)))
        
        toolBar.setItems([moveLeftButton, space, moveRightButton, flexible, doneButton], animated: true)
        textField.inputAccessoryView = toolBar
        
        return textField
    }

    func makeCoordinator() -> XxCustomTextField.Coordinator {
        return Coordinator(text: $text, selectedCell: $selectedCell)
    }

    func updateUIView(_ uiView: UITextField, context: UIViewRepresentableContext<XxCustomTextField>) {
        uiView.text = text
        if isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }
}

class XxCustomUITextField: UITextField {
    
    @Binding var numberOfCells: Int
    @Binding var selectedCell: Int
    
    init(numberOfCells: Binding<Int>, selectedCell: Binding<Int>) {
        _numberOfCells = numberOfCells
        _selectedCell = selectedCell
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func moveLeft() -> Void {
        if selectedCell > 0 {
            self.selectedCell -= 1
        }
    }
    
    @objc func moveRight(button: UIBarButtonItem) -> Void {
        if selectedCell < numberOfCells - 1 {
            self.selectedCell += 1
        }
    }
    
    @objc func done(button: UIBarButtonItem) -> Void {
        self.resignFirstResponder()
    }
}