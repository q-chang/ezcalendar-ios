//
//  Date+.swift
//  Demo
//
//  Created by Wisanu Paunglumjeak on 12/1/2568 BE.
//

import Foundation

extension Date {
    static func from(year: Int, month: Int, day: Int, calendar: Calendar = Calendar.current) -> Date?{
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = 0
        dateComponents.minute = 0
        dateComponents.second = 0
        return calendar.date(from: dateComponents)
    }
    
    func addingComponentsOfDate(year: Int? = nil, month: Int? = nil, day: Int? = nil) -> Date? {
        
        if year != nil && month != nil && day != nil {
            return self
        }
        
        var dateCoponents = DateComponents()
        
        if let year {
            dateCoponents.year = year
        }
        
        if let month {
            dateCoponents.month = month
        }
        
        if let day {
            dateCoponents.day = day
        }

        return Calendar.current.date(byAdding: dateCoponents, to: self)
    }
    
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }

    var startOfMonth: Date {

        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.year, .month], from: self)

        return  calendar.date(from: components)!
    }

    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }

    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar(identifier: .gregorian).date(byAdding: components, to: startOfMonth)!
    }
    
    func toString(
        dateFormat: String,
        locale: Foundation.Locale = Foundation.Locale(identifier: "en_US")
    ) -> String {
        let format = DateFormatter()
        format.dateFormat = dateFormat
        format.locale = locale
        return format.string(from: self)
    }
    
    func get(_ component: Calendar.Component, calendar: Calendar = Calendar.current) -> Int {
        return calendar.component(component, from: self)
    }
}
