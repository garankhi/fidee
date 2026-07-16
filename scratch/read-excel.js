const xlsx = require('xlsx');
const workbook = xlsx.readFile('D:/Seeddata/Data.xlsx');
const sheet_name_list = workbook.SheetNames;
const data = xlsx.utils.sheet_to_json(workbook.Sheets[sheet_name_list[0]]);
console.log('Headers:', Object.keys(data[0]));
console.log('First row:', data[0]);
