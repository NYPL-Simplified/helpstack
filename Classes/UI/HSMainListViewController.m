//  HAZendDeskMainViewController.m
//
//Copyright (c) 2014 HelpStack (http://helpstack.io)
//
//Permission is hereby granted, free of charge, to any person obtaining a cop
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in
//all copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//THE SOFTWARE.

#import "HSMainListViewController.h"
#import "HSArticleDetailViewController.h"
#import "HSGroupViewController.h"
#import "HSHelpStack.h"
#import "HSNewTicket.h"
#import "HSKBSource.h"
#import "HSTicketSource.h"
#import "HSAppearance.h"
#import "HSTableView.h"
#import "HSTableViewCell.h"
#import "HSLabel.h"
#import "HSTableViewHeaderCell.h"
#import <MessageUI/MessageUI.h>
#import "HSActivityIndicatorView.h"
#import "HSTableFooterCreditsView.h"
#import "HSUtility.h"

/*
 To report issue using email:
 ->If ticketDelegate is not set, default email client is open and mail is prepared using given companyEmailAddress.
 */

@interface HSMainListViewController () <MFMailComposeViewControllerDelegate> {
    UINavigationController* newTicketNavController;
}

@property(nonatomic, strong) HSActivityIndicatorView *loadingView;

@end

@implementation HSMainListViewController

BOOL finishedLoadingKB = NO;
BOOL finishedLoadingTickets = NO;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.kbSource = [HSKBSource createInstance];
    self.ticketSource = [HSTicketSource createInstance];
    
    self.loadingView = [[HSActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 20.0, 20.0)];
    UIBarButtonItem *rightBarButton = [[UIBarButtonItem alloc] initWithCustomView:self.loadingView];
    self.navigationItem.rightBarButtonItem = rightBarButton;
    
    HSAppearance* appearance = [[HSHelpStack instance] appearance];
    self.view.backgroundColor = [appearance getBackgroundColor];
    self.tableView.tableFooterView = [UIView new];
    // Fetching KB and Tickets
    [self startLoadingAnimation];
    [self refreshKB];
    [self refreshMyIssue];
    
    [self addCreditsToTable];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

#pragma mark - KBArticles and Issues Fetch

- (void)refreshKB
{
    // Fetching latest KB article from server.
    [self.kbSource prepareKB:^{
        finishedLoadingKB = YES;
        [self onKBorTicketsFetched];
        [self reloadKBSection];
    } failure:^(NSError* e){
        finishedLoadingKB = YES;
        [self onKBorTicketsFetched];

        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Couldn't Load Article" message:@"There was an error loading this article. Please check your internet connection." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    }];
}

- (void)refreshMyIssue
{
    // Fetching latest Tickets from server.
    [self.ticketSource prepareTicket:^{
        finishedLoadingTickets = YES;
        [self onKBorTicketsFetched];
        // If there are no ticket, no need to reload table
        if([self.ticketSource ticketCount]!=0){
            [self reloadTicketsSection];
        }
    } failure:^(NSError* e){
        finishedLoadingTickets = YES;
        [self onKBorTicketsFetched];

        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Error loading the previous issues." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];

    }];
}

- (void)reloadKBSection
{
    NSIndexSet *sectionSet = [NSIndexSet indexSetWithIndex:0];
    [self.tableView reloadSections:sectionSet withRowAnimation:UITableViewRowAnimationNone];
}

- (void)reloadTicketsSection{
    [self.tableView reloadData];
}

- (void)onKBorTicketsFetched{
    if(finishedLoadingKB && finishedLoadingTickets){
        [self stopLoadingAnimation];
    }
}

- (void)startLoadingAnimation
{
    self.loadingView.hidden = NO;
    [self.loadingView startAnimating];
}

- (void)stopLoadingAnimation
{
    [self.loadingView stopAnimating];
    self.loadingView.hidden = YES;
}

- (void)addCreditsToTable {
    if ([[HSHelpStack instance] showCredits]) {
        HSTableFooterCreditsView* footerView = [[HSTableFooterCreditsView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 100)];
        self.tableView.tableFooterView = footerView;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        return [self.kbSource kbCount:HAGearTableTypeSearch];
    } else {
        return [self.kbSource kbCount:HAGearTableTypeDefault];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.searchDisplayController.searchResultsTableView) {
        
        static NSString *CellIdentifier = @"Cell";
        
        HSTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[HSTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        
        HSKBItem* article = [self.kbSource table:HAGearTableTypeSearch kbAtPosition:indexPath.row];
        cell.textLabel.text = article.title;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
        return cell;
        
    } else {
        
        static NSString *CellIdentifier = @"HelpCell";

        HSTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[HSTableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        cell.textLabel.textAlignment = NSTextAlignmentLeft;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;

        HSKBItem* article = [self.kbSource table:HAGearTableTypeDefault kbAtPosition:indexPath.row];
        cell.textLabel.text = article.title;

        return cell;
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
    scrollView.scrollEnabled = true;
}



#pragma mark - TableView Delegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView == self.searchDisplayController.searchResultsTableView) {
      [self table:HAGearTableTypeSearch articleSelectedAtIndexPath:indexPath.row];
    } else {
      [self table:HAGearTableTypeDefault articleSelectedAtIndexPath:indexPath.row];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)table:(HAGearTableType)table articleSelectedAtIndexPath:(NSInteger) position
{
    HSKBItem* selectedKB = [self.kbSource table:table kbAtPosition:position];
    HSKBItemType type = HSKBItemTypeArticle;
    type = selectedKB.itemType;

    // KB is section, so need to call another tableviewcontroller
    if (type == HSKBItemTypeSection) {
        HSKBSource* newSource = [self.kbSource sourceForSection:selectedKB];
        HSGroupViewController* controller = [self.storyboard instantiateViewControllerWithIdentifier:@"HAGroupController"];
        controller.kbSource = newSource;
        controller.selectedKB = selectedKB;
        [self.navigationController pushViewController:controller animated:YES];
    }
    else {
        HSArticleDetailViewController* controller = [self.storyboard instantiateViewControllerWithIdentifier:@"HAArticleController"];
        controller.article = selectedKB;
        [self.navigationController pushViewController:controller animated:YES];
    }
}

- (IBAction)cancelPressed:(UIBarButtonItem *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterArticlesforSearchString:searchString];
    return NO;
}

- (void)filterArticlesforSearchString:(NSString*)string
{
    [self.kbSource filterKBforSearchString:string success:^{
        [self.searchDisplayController.searchResultsTableView reloadData];
    } failure:^(NSError* e){

    }];
}

#pragma mark - MailClient
- (void) startMailClient
{
    if ([MFMailComposeViewController canSendMail])
    {
        MFMailComposeViewController* mailer = [[MFMailComposeViewController alloc] init];
        mailer.mailComposeDelegate = self;
        
        [mailer setToRecipients:@[[self.ticketSource supportEmailAddress]]];
        [mailer setSubject:@"Help"];
        [mailer setMessageBody:[HSUtility deviceInformation] isHTML:NO];
        
        mailer.modalPresentationStyle = UIModalPresentationCurrentContext;
        
        [self presentViewController:mailer animated:YES completion:nil];
    } else
    {
        
        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Unable to send email" message:@"Have you configured any email account in your phone? Please check." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertView show];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if (result == MFMailComposeResultSent) {
        UIAlertView* mailSentAlert = [[UIAlertView alloc] initWithTitle:@"Mail sent." message:@"Thanks for contacting me. Will reply asap." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [mailSentAlert show];
    }
    
}

@end
