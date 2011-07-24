/*
 * Copyright 2011 Ziminji
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at:
 * 
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "ZIMSqlCreateTableStatement.h"

@implementation ZIMSqlCreateTableStatement

- (id) initWithXML: (NSData *)xml error: (NSError **)error {
	if ((self = [super init])) {
		_table = nil;
		_temporary = NO;
		_columnDictionary = [[NSMutableDictionary alloc] init];
		_columnArray = [[NSMutableArray alloc] init];
		_primaryKey = nil;
		_unique = nil;
        //_depth = 0;
        _counter = 0;
        _error = error;
        if (xml != nil) {
			NSXMLParser *parser = [[NSXMLParser alloc] initWithData: xml];
			[parser setDelegate: self];
			[parser parse];
			[parser release];
		}
	}
	return self;
}

- (id) init {
    NSError *error;
    return [self initWithXML: nil error: &error];
}

- (void) dealloc {
	[_columnDictionary release];
	[_columnArray release];
	[super dealloc];
}

- (void) table: (NSString *)table {
	[self table: table temporary: NO];
}

- (void) table: (NSString *)table temporary: (BOOL)temporary {
	_table = [ZIMSqlExpression prepareIdentifier: table];
	_temporary = temporary;
}

- (void) column: (NSString *)column type: (NSString *)type {
	if ([_columnDictionary objectForKey: column] == nil) {
		[_columnArray addObject: column];
	}
	[_columnDictionary setObject: [NSString stringWithFormat: @"%@ %@", column, type] forKey: column];
}

- (void) column: (NSString *)column type: (NSString *)type defaultValue: (NSString *)value {
	if ([_columnDictionary objectForKey: column] == nil) {
		[_columnArray addObject: column];
	}
	[_columnDictionary setObject: [NSString stringWithFormat: @"%@ %@ %@", column, type, value] forKey: column];
}

- (void) column: (NSString *)column type: (NSString *)type primaryKey: (BOOL)primaryKey {
	if ([_columnDictionary objectForKey: column] == nil) {
		[_columnArray addObject: column];
	}
	if (primaryKey) {
		[_columnDictionary setObject: [NSString stringWithFormat: @"%@ %@ PRIMARY KEY", column, type] forKey: column];
	}
	else {
		[_columnDictionary setObject: [NSString stringWithFormat: @"%@ %@", column, type] forKey: column];
	}
}

- (void) column: (NSString *)column type: (NSString *)type unique: (BOOL)unique {
	if ([_columnDictionary objectForKey: column] == nil) {
		[_columnArray addObject: column];
	}
	if (unique) {
		[_columnDictionary setObject: [NSString stringWithFormat: @"%@ %@ UNIQUE", column, type] forKey: column];
	}
	else {
		[_columnDictionary setObject: [NSString stringWithFormat: @"%@ %@", column, type] forKey: column];
	}
}

- (void) primaryKey: (NSArray *)columns {
	if (columns != nil) {
		for (NSString *column in columns) {
			if ([_columnDictionary objectForKey: column] == nil) {
				@throw [NSException exceptionWithName: @"ZIMSqlException" reason: [NSString stringWithFormat: @"Must declare column '%@' before primary key can be assigned.", column] userInfo: nil];
			}
		}
		_primaryKey = [NSString stringWithFormat: @"PRIMARY KEY (%@)", [columns componentsJoinedByString: @", "]];
	}
	else {
		_primaryKey = nil;
	}
}

- (void) unique: (NSArray *)columns {
	if (columns != nil) {
		for (NSString *column in columns) {
			if ([_columnDictionary objectForKey: column] == nil) {
				@throw [NSException exceptionWithName: @"ZIMSqlException" reason: [NSString stringWithFormat: @"Must declare column '%@' before applying unique constraint.", column] userInfo: nil];
			}
		}
		_unique = [NSString stringWithFormat: @"UNIQUE (%@)", [columns componentsJoinedByString: @", "]];
	}
	else {
		_unique = nil;
	}
}

- (NSString *) statement {
	NSMutableString *sql = [[[NSMutableString alloc] init] autorelease];
	
	[sql appendString: @"CREATE"];

	if (_temporary) {
		[sql appendString: @" TEMPORARY"];
	}
	
	[sql appendFormat: @" TABLE %@ (", _table];

	int i = 0;
	for (NSString *column in _columnArray) {
		if (i > 0) {
			[sql appendFormat: @", %@", (NSString *)[_columnDictionary objectForKey: column]];
		}
		else {
			[sql appendString: (NSString *)[_columnDictionary objectForKey: column]];
		}
		i++;
	}

	if (_primaryKey != nil) {
		[sql appendFormat: @", %@", _primaryKey];
	}

	if (_unique != nil) {
		[sql appendFormat: @", %@", _unique];
	}

	[sql appendString: @");"];
	
	return sql;
}

- (void) parser: (NSXMLParser *)parser didStartElement: (NSString *)element namespaceURI: (NSString *)namespaceURI qualifiedName: (NSString *)qualifiedName attributes: (NSDictionary *)attributes {
    if (_counter < 1) {
        if ([element isEqualToString: @"table"]) {
            [self table: [attributes objectForKey: @"name"]];
        }
        else if ([element isEqualToString: @"column"]) {
            NSString *columnName = [attributes objectForKey: @"name"];
            NSString *columnType = [[[attributes objectForKey: @"type"] uppercaseString] stringByReplacingOccurrencesOfString: @"_" withString: @" "];
			NSString *columnUnsigned = [attributes objectForKey: @"unsigned"];
			if ((columnUnsigned != nil) && [[columnUnsigned uppercaseString] boolValue]) {
				columnType = [NSString stringWithFormat: @"UNSIGNED %@", columnType];
            }
            NSString *columnSize = [attributes objectForKey: @"size"];
            if (columnSize != nil) {
                NSString *columnScale = [attributes objectForKey: @"scale"];
                if (columnScale != nil) {
                    columnType = [NSString stringWithFormat: @"%@(%@, %@)", columnType, columnSize, columnScale];
                }
                else {
                    columnType = [NSString stringWithFormat: @"%@(%@)", columnType, columnSize];
                }
            }
            NSString *columnValue = [attributes objectForKey: @"auto-increment"];
            if ((columnValue != nil) && [[columnValue uppercaseString] boolValue]) {
                [self column: columnName type: columnType defaultValue: ZIMSqlDefaultValueIsAutoIncremented];
            }
            else {
                NSString *columnKey = [attributes objectForKey: @"key"];
                if ((columnKey != nil) && [[columnKey lowercaseString] isEqualToString: @"primary"]) {
                    if (_primaryKey != nil) {
                        _primaryKey = [_primaryKey substringWithRange: NSMakeRange(13, [_primaryKey length] - 14)];
                        _primaryKey = [NSString stringWithFormat: @"PRIMARY KEY (%@, %@)", _primaryKey, columnName];
                    }
                    else {
                        _primaryKey = [NSString stringWithFormat: @"PRIMARY KEY (%@)", columnName];
                    }
                }
                columnValue = [attributes objectForKey: @"default"];
                if (columnValue != nil) {
                    [self column: columnName type: columnType defaultValue: ZIMSqlDefaultValue(columnValue)];
                }
                else {
                    [self column: columnName type: columnType];
                }
            }
        }
    }
}

- (void) parser: (NSXMLParser *)parser didEndElement: (NSString *)element namespaceURI: (NSString *)namespaceURI qualifiedName: (NSString *)qualifiedName {
    if ([element isEqualToString: @"table"]) {
        _counter++;
    }
}

- (void) parser: (NSXMLParser *)parser parseErrorOccurred: (NSError *)error {
    if (_error) {
        *_error = error;
    }
}

@end
