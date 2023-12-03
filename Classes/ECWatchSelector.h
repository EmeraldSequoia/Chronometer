//
//  ECWatchSelector.h
//  Emerald Chronometer
//
//  Created by Steve Pucci 11/2008.
//  Copyright Emerald Sequoia LLC 2008. All rights reserved.

@interface ECWatchSelector : UITableViewController <UITableViewDataSource, UITableViewDelegate> {
    bool editingOnly;
}

-(id) init;
-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
-(void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath;
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
-(void)setEditingOnly:(bool)editingOnly;

@end
