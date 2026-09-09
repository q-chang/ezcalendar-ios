//
//  ContentView.swift
//  Demo
//
//  Created by Wisanu Paunglumjeak on 12/1/2568 BE.
//

import SwiftUI
import EZCalendar

struct ContentView: View {
    
    @EnvironmentObject var router: Router
    
    var body: some View {
        VStack(spacing: 16) {
            Button("Item") {
                router.navigate(to: Destination.item)
            }
            
            Button("Horizontal Pagging") {
                router.navigate(to: Destination.horizontal_paging)
            }
            
            Button("Agenda (Calendar + List)") {
                router.navigate(to: Destination.agenda)
            }
        }
        .padding()
    }
}

#Preview {
    RouterView()
}
