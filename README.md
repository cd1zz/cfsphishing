## Notes
Every time you change the FunctionApp code, be sure to repackage the FunctionApp.zip file. The zip file is what is referenced when the solution is deployed. The local .python_packages folder is necessary when deploying in this "push to deploy" manner. 

## Deploy the Solution

### Step 1: Deploy the Function App

Click the button below to deploy the Function App. You will be prompted to enter the resource group name, location, and Function App name.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fcd1zz%2Fcfsphishing%2Fmain%2Ffunctionapp_deploy.json)

### Step 2: Deploy the Logic App

#### Run the logicapp_prep.py file to search and replace the default functionapp name with the name of the function app you just created in step one:
  python logicapp_prep.py logicapp_original.json

This is required because the ARM templates do not support dynamic JSON keys. 

Click the button below to deploy the Logic App. You will be prompted to enter the resource group name, location, and Logic App name.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fcd1zz%2Fcfsphishing%2Fmain%2Flogicapp_deploy.json)
