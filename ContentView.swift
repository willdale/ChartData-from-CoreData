//
//  ContentView.swift
//  Chart Data from Core Data
//
//  Created by Will Dale on 19/11/2020.
//

/*
 
 A demo of getting data out of Core Data (or any other data store), making sure that every day a data point even if it's at 0.

 The Chart solution I'm using here is SwiftUICharts: https://github.com/AppPear/ChartView version 1.5.4
 
 The fundamentals of this should work with other charting solutions with some editing.
 
 Test database:
    Entity: Data
    Attributes: date : Date
                measurements : Double
                uuid : UUID
 
  */

import SwiftUI
import CoreData
import SwiftUICharts

// MARK: Main View
// Add data / set predicate, etc...
struct ContentView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @State var range = ChartRange.week
    @State var startDate = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                Picker(selection: $range, label: Text("Select Range")) {
                    Text("Week").tag(ChartRange.week)
                    Text("Month").tag(ChartRange.month)
                    Text("Year").tag(ChartRange.year)
                }
                .pickerStyle(SegmentedPickerStyle())
                DatePicker(selection: $startDate, displayedComponents: .date, label: {
                    Text("Select End Date")
                })
                .labelsHidden()
                .datePickerStyle(WheelDatePickerStyle())
                
                // Pass selection into subview
                DataView(startDate, range)
            }
            
                .navigationTitle("Charts")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        
                        // Create test data
                        Button(action: {
                            
                            var calendar = Calendar.current
                            calendar.timeZone = NSTimeZone.local
                            
                            for index in 0..<100 {
                                let newData = Data(context: viewContext)
                                newData.measurement = Double.random(in: 0..<800)
                                newData.date = calendar.date(byAdding: .day, value: -index, to: Date())
                            }
                            // No need for me to save for a test
                            
//                            do {
//                                try viewContext.save()
//                            } catch {
//                                // Replace this implementation with code to handle the error appropriately.
//                                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
//                                let nsError = error as NSError
//                                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
//                            }
                        }, label: {
                            Label("Add Items", systemImage: "plus")
                        })
                        
                    }
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

// MARK: Sub View
struct DataView: View {
    
    @Environment(\.managedObjectContext) private var viewContext
    
    var dataPoints  : FetchRequest<Data>
    var startDate   : Date
    var endDate     : Date
    var chartRange  : ChartRange
    
    var body: some View {
        VStack {
            LineView(data: ChartHelper.getPeakflowData(startDate, chartRange, dataPoints))
            HStack {
                Text(startDate, formatter: dateFormat)
                Spacer()
                Text(endDate, formatter: dateFormat)
            }.padding(.horizontal)
            Spacer()
        }
    }
    
    init(_ date: Date, _ chartRange: ChartRange) {
        
        let dateRange       = ChartHelper.dateRange(date, chartRange, "date")
        let datePredicate   = dateRange.datePredicate
        
        self.startDate = dateRange.firstDate
        self.chartRange = chartRange
        self.endDate    = dateRange.lastDate
        self.dataPoints = FetchRequest<Data>(entity: Data.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Data.date, ascending: false)], predicate: datePredicate)
        
    }
    
    var dateFormat : DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        return dateFormatter
    }
}

// MARK: Models
enum ChartRange {
    case week
    case month
    case year
}

struct TemporaryChartData: Identifiable {
    let id              : UUID
    var Measurement     : Double
    let date            : Date
    var index           : Int
}


// MARK: Chart Functions
/// Functions for getting data from Core Data into a chart
struct ChartHelper {
    /// Gets end date of the range and which range of dates from Range ENUM
    /// - Parameters:
    ///   - date: End Date
    ///   - range: .week, . month or .year
    /// - Returns: core data predicate AND first date in range AND equally spaced dates AND last date
    static func dateRange(_ date: Date, _ range: ChartRange, _ predicateKey: String) -> (datePredicate: NSCompoundPredicate, firstDate: Date, lastDate: Date) {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        
        // End date
        let requestedDate   : Date = calendar.startOfDay(for: date)
        let lastDate        = calendar.date(byAdding: .day, value: 1, to: requestedDate)
        var firstDate       : Date
        
        // Sets the first date for predicate based on the chosen end date and range
        // Can be used for generating an array of labels to put on the X Axis of Chart if required
        switch range {
        case .week:
            firstDate   = calendar.date(byAdding: .day, value: -7, to: lastDate ?? Date()) ?? Date()
        case .month:
            firstDate   = calendar.date(byAdding: .day, value: -28, to: lastDate ?? Date()) ?? Date()
        case .year:
            firstDate   = calendar.date(byAdding: .day, value: -365, to: lastDate ?? Date()) ?? Date()
        }
        
        // if using in multiple entity you can set the predicateKey dynamically
        let fromPredicate   = NSPredicate(format: "\(predicateKey) >= %@", firstDate as NSDate)
        let toPredicate     = NSPredicate(format: "\(predicateKey) < %@",  lastDate! as NSDate)
        let datePredicate   = NSCompoundPredicate(andPredicateWithSubpredicates: [fromPredicate, toPredicate])
        
        return (datePredicate, firstDate, requestedDate)
    }
    
    /// Add zeroed data to an array with dates matched to request
    /// - Parameters:
    ///   - startDate: First date of request
    ///   - chartRange: .week, .month, .year
    /// - Returns: Array of blank data
    static func addBlankData(_ startDate: Date, _ chartRange: ChartRange) -> [TemporaryChartData] {
        var chartData : [TemporaryChartData] = []
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        var date : Date = startDate
        var range: ClosedRange<Int>
        switch chartRange {
        case .week:
            range = 1...7
        case .month:
            range = 1...28
        case .year:
            range = 1...365
        }
        for _ in range {
            chartData.append(TemporaryChartData(id: UUID(), Measurement: 0, date: date, index: 0))
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return chartData
    }
    
    /// Over write blank data if a data point exists in Core Data
    /// - Parameters:
    ///   - startDate: First date of request
    ///   - chartRange: .week, .month, .year
    ///   - dataPoints: Request from Core Data
    /// - Returns: Array of Doubles for use in chart
    static func getPeakflowData(_ startDate: Date, _ chartRange: ChartRange, _ dataPoints: FetchRequest<Data>) -> [Double] {
        var calendar = Calendar.current
        calendar.timeZone = NSTimeZone.local
        var chartData: [TemporaryChartData] = ChartHelper.addBlankData(startDate, chartRange)
        // Loop over the blank
        for dataPoint in dataPoints.wrappedValue {
            // Each loop check if any dates mach the cuurent objects date
            for i in 0 ..< chartData.count {
                if calendar.isDate(dataPoint.date!, inSameDayAs: calendar.date(byAdding: .day, value: i, to: startDate)!) {
                    // If the dates match check if an entry exists for it
                    if chartData[i].Measurement == 0 {
                        // If there is no entry over-right the blank data with data from Core Data
                        chartData[i] = TemporaryChartData(id: chartData[i].id, Measurement: Double(dataPoint.measurement), date: chartData[i].date, index: 0)
                        // Index allows for averaging later
                        chartData[i].index += 1
                    } else {
                        // If data already exists add them together
                        chartData[i].Measurement += Double(dataPoint.measurement)
                        // Index allows for averaging later
                        chartData[i].index += 1
                    }
                }
            }
        }
        var finalData : [Double] = []
        // Make an array of Doubles by looping over TemporaryChartData
        // Average out data point using the index
        for data in chartData {
            if data.Measurement != 0 {
                var average : Double
                average = data.Measurement / Double(data.index)
                finalData.append(average)
            } else {
                finalData.append(data.Measurement)
            }
        }
        return finalData
    }
}




