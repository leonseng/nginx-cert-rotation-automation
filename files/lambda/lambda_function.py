import urllib3
import boto3

def lambda_handler(event, context):
  # Create EC2 client
  ec2_client = boto3.client("ec2")
  http = urllib3.PoolManager()

  # Filter based on tag
  filters = [{"Name": "tag:${nginx_ec2_target_tag}", "Values": ["*"]}]

  # Describe instances with filter
  response = ec2_client.describe_instances(Filters=filters)

  # Extract private IP addresses
  ip_addresses = []
  for reservation in response["Reservations"]:
    for instance in reservation["Instances"]:
      private_ip = instance.get("PrivateIpAddress")
      if private_ip:
        ip_addresses.append(private_ip)

  found = len(ip_addresses)
  updated = 0

  # Loop through IP addresses and call update endpoint
  for ip_address in ip_addresses:
    try:
        response = http.request('POST', f"http://{ip_address}:8080/update")
        if response.status == 201:
            updated += 1
        else:
            print(f"Failed to trigger update on {ip_address}")
    except urllib3.exceptions.HTTPError as e:
        # Handle HTTP errors here
        print(f"HTTP error: {e}")
    except urllib3.exceptions.MaxRetryError as e:
        # Handle retries exhaustion here
        print(f"Connection failed after retries: {e}")
    except Exception as e:
        # Handle other exceptions here
        print(f"Unexpected error: {e}")

  return {
      "statusCode": 200,
      "body": f"Updated {updated}/{found} instances."
  }