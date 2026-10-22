// swift-tools-version: 5.9
import PackageDescription
let package = Package(name:"DailyOfficeCore",platforms:[.macOS(.v14)],products:[.library(name:"DailyOfficeCore",targets:["DailyOfficeCore"])],targets:[
.target(name:"DailyOfficeCore",path:"DailyOffice",exclude:["App.swift","Views.swift","DefaultSkills.json"],sources:["Models.swift","Services.swift","OfficeStore.swift"]),
.testTarget(name:"DailyOfficeTests",dependencies:["DailyOfficeCore"],path:"Tests")])
