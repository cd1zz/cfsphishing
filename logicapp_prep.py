import json
import sys

def replace_function_name_in_json(file_path, old_function_name, new_function_name, output_file_path):
    # Load the JSON from the file
    with open(file_path, 'r') as f:
        data = json.load(f)

    # Recursively search and replace the function name in both keys and values
    def replace_value(obj):
        if isinstance(obj, dict):
            keys_to_replace = [key for key in obj if old_function_name in key]
            for key in keys_to_replace:
                new_key = key.replace(old_function_name, new_function_name)
                obj[new_key] = obj.pop(key)
            
            for key, value in obj.items():
                if isinstance(value, str) and old_function_name in value:
                    obj[key] = value.replace(old_function_name, new_function_name)
                else:
                    replace_value(value)
        elif isinstance(obj, list):
            for index, item in enumerate(obj):
                if isinstance(item, str) and old_function_name in item:
                    obj[index] = item.replace(old_function_name, new_function_name)
                else:
                    replace_value(item)

    replace_value(data)

    # Write the modified JSON to the output file
    with open(output_file_path, 'w') as f:
        json.dump(data, f, indent=4)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python logicapp_prep.py <path_to_json_file>")
        sys.exit(1)

    json_file_path = sys.argv[1]
    new_function_name = input("Enter the new FunctionApp name: ")
    old_function_name = "ParseEmailVT"
    output_file_path = "logicapp_deploy.json"

    replace_function_name_in_json(json_file_path, old_function_name, new_function_name, output_file_path)
    print(f"Modified JSON saved to {output_file_path}")
