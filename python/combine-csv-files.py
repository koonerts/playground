import glob
import os
import pandas as pd


def combine_data_1():
    client_filter = 'cvs'
    month_filter = 'feb'
    path = f"C:/My Projects/other/Call_Center_Data/combine-files/{month_filter}/{client_filter}"

    sf_basic = pd.DataFrame()
    sf_detailed = pd.DataFrame()
    in_contact = pd.DataFrame()

    for f in glob.glob(os.path.join(path, f"sf-basic-{month_filter}*.xlsx")):
        if f.endswith('.xlsx'):
            df = pd.read_excel(f, sheet_name=0, engine='openpyxl')
        else:
            df = pd.read_excel(f)

        df = df[df['Call Object Identifier'].notna()]
        sf_basic = sf_basic.append(df, ignore_index=True)

    for f in glob.glob(os.path.join(path, f"sf-detailed-{month_filter}*.xlsx")):
        if f.endswith('.xlsx'):
            df = pd.read_excel(f, sheet_name=0, engine='openpyxl', usecols=lambda x: x not in ['Case Origin', 'Type'])
        else:
            df = pd.read_excel(f, usecols=lambda x: x not in ['Case Origin', 'Type'])

        df = df[df['Case Number'].notna()]
        sf_detailed = sf_detailed.append(df, ignore_index=True)

    for f in glob.glob(os.path.join(path, f"incontact-{month_filter}*.xls")):
        if f.endswith('.xlsx'):
            df = pd.read_excel(f, sheet_name=0, engine='openpyxl')
        else:
            df = pd.read_excel(f)
        df = df[df['Agent ID'].notna()]
        in_contact = in_contact.append(df, ignore_index=True)

    salesforce_data_all = sf_basic.merge(sf_detailed, how='left', left_on='Case', right_on='Case Number')
    merged_data = in_contact.merge(salesforce_data_all, how='left', left_on='Contact ID', right_on='Call Object Identifier')
    merged_data = merged_data.rename(columns={"Date": "Activity Date"})
    merged_data = merged_data.rename(columns={"Case Number": "Case Number2"})
    merged_data = merged_data.rename(columns={"Case": "Case Number"})

    cols = ['Contact ID', 'Master Contact ID', 'Contact Start Date Time', 'Contact End Date Time', 'Year', 'Week', 'Agent ID', 'Skill Name', 'Skill Direction', 'ANI/From', 'DNIS/To',
            'Conference Time', 'Hold Time', 'Talk Time', 'Callback Time', 'Routing Time', 'Handle Time', 'Active Talk Time', 'Abandon Time', 'Inqueue Time', 'ACW Time', 'Transferred',
            'Case Number', 'Account Name', 'Client ID', 'Activity Date', 'Date/Time Opened', 'Date/Time Closed', 'Last Activity', 'Contact.Case HoverID', 'Name', 'Phone',
            'Mailing State/Province', 'Employment Status', 'Benefit Class', 'Business Unit', 'Age', 'Contact Name', 'Subject', 'Case Origin', 'Case Owner', 'Type',
            'Detail', 'Disposition', 'Topic1', 'Priority', 'Status', 'Age (Days)', 'Business Hours Age (Days)', 'First call resolution']

    # merged_data.to_excel('C:/My Projects/other/Call_Center_Data/joined_data.xlsx', columns=cols)
    file_name = month_filter or 'all_data'
    merged_data.sort_values(by='Contact ID', inplace=True)

    print(f'Missing cols: {[col for col in cols if col not in merged_data.columns.to_list()]}')
    cols = [col for col in cols if col in merged_data.columns.to_list()]
    with pd.ExcelWriter(f'C:/My Projects/other/Call_Center_Data/combine-files/{month_filter}/{client_filter}/{file_name+"_data"}.xlsx',
                        engine='xlsxwriter',
                        datetime_format='YYYY-MM-DD HH:MM:SS',
                        date_format='YYYY-MM-DD') as excel_writer:

        merged_data['Contact Start Date Time'] = pd.to_datetime(merged_data['Contact Start Date Time'])
        merged_data['Contact End Date Time'] = pd.to_datetime(merged_data['Contact End Date Time'])
        merged_data.to_excel(excel_writer, columns=cols, sheet_name='Sheet1', index=False)
        workbook = excel_writer.book
        num_format = workbook.add_format({'num_format': '0'})
        worksheet = excel_writer.sheets['Sheet1']
        worksheet.set_column('A:A', 13, num_format)
        worksheet.set_column('B:B', 17, num_format)


def combine_data_2():
    path = "C:/My Projects/other/Call_Center_Data/Case Analytics/files"

    salesforce = pd.DataFrame()
    in_contact = pd.DataFrame()

    month_filter = ''
    client_filter = 'homedepot'

    for f in glob.glob(os.path.join(path, f"{client_filter}*salesforce-{month_filter}*.xlsx")):
        df = pd.read_excel(f)
        df = df[df['Case Number'].notna()]
        salesforce = salesforce.append(df, ignore_index=True)

    for f in glob.glob(os.path.join(path, f"{client_filter}*incontact-{month_filter}*.xls")):
        df = pd.read_excel(f)
        df = df[df['Agent ID'].notna()]
        in_contact = in_contact.append(df, ignore_index=True)

    merged_data = in_contact.merge(salesforce, how='left', left_on='Contact ID', right_on='CallReference')
    merged_data = merged_data.rename(columns={"Date": "Activity Date"})

    # cols = ['Contact ID', 'Master Contact ID', 'Contact Start Date Time', 'Contact End Date Time', 'Year', 'Week', 'Agent ID', 'Skill Name', 'Skill Direction', 'ANI/From', 'DNIS/To',
    #         'Conference Time', 'Hold Time', 'Talk Time', 'Callback Time', 'Routing Time', 'Handle Time', 'Active Talk Time', 'Abandon Time', 'Inqueue Time', 'ACW Time', 'Transferred',
    #         'Case Number', 'Account Name', 'Client ID', 'Activity Date', 'Date/Time Opened', 'Date/Time Closed', 'Last Activity', 'Contact.Case HoverID', 'Name', 'Phone',
    #         'Mailing State/Province', 'Employment Status', 'Benefit Class', 'Business Unit', 'Age', 'Contact Name', 'Subject', 'Case Origin', 'Case Owner', 'Type',
    #         'Detail', 'Disposition', 'Topic1', 'Priority', 'Status', 'Age (Days)', 'Business Hours Age (Days)', 'First call resolution']

    cols = ['Contact ID', 'Master Contact ID', 'Contact Start Date Time', 'Contact End Date Time', 'Year', 'Week', 'Agent ID', 'Skill Name', 'Skill Direction',
            'ANI/From', 'DNIS/To', 'Conference Time', 'Hold Time', 'Talk Time', 'Callback Time', 'Routing Time', 'Handle Time', 'Active Talk Time',
            'Abandon Time', 'Inqueue Time', 'ACW Time', 'Transferred',

            'Case Number', 'Account Name', 'Client ID', 'Opened Date', 'Last Activity', 'Contact: Last Modified Date', 'Contact.Case HoverID',
            'Case Origin', 'Case Owner', 'Type', 'Disposition', 'Description', 'Topic1', 'Priority', 'Status', 'Business Hours Age (Days)',
            'SLA', 'SLA Age Days', 'First call resolution']

    # merged_data.to_excel('C:/My Projects/other/Call_Center_Data/joined_data.xlsx', columns=cols)
    file_name = client_filter or 'all_data'

    merged_data.sort_values(by='Contact ID', inplace=True)
    merged_data.to_csv(f'C:/My Projects/other/Call_Center_Data/Case Analytics/files/{file_name+"_oe_data"}.csv', columns=cols)


combine_data_1()