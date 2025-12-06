#!/usr/bin/env python3
"""
Stable Diffusion EC2 API Client
Simple script to test and interact with the deployed API
"""

import requests
import argparse
import sys
from pathlib import Path
from PIL import Image
import io
import json

class StableDiffusionClient:
    def __init__(self, api_url: str, timeout: int = 300):
        self.api_url = api_url.rstrip('/')
        self.timeout = timeout
        
    def health_check(self) -> dict:
        """Check API health status"""
        try:
            response = requests.get(
                f"{self.api_url}/health",
                timeout=10
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.RequestException as e:
            return {"error": str(e)}
    
    def generate_image(
        self,
        prompt: str,
        negative_prompt: str = "",
        num_inference_steps: int = 50,
        guidance_scale: float = 7.5,
        output_file: str = None
    ) -> bool:
        """
        Generate an image and save to file
        Returns: True if successful, False otherwise
        """
        try:
            print(f"📝 Generating image with prompt: {prompt}")
            
            response = requests.post(
                f"{self.api_url}/generate",
                files={
                    "prompt": (None, prompt),
                    "negative_prompt": (None, negative_prompt),
                    "num_inference_steps": (None, str(num_inference_steps)),
                    "guidance_scale": (None, str(guidance_scale)),
                },
                timeout=self.timeout
            )
            response.raise_for_status()
            
            # Save image
            if output_file:
                with open(output_file, 'wb') as f:
                    f.write(response.content)
                print(f"✓ Image saved to: {output_file}")
            else:
                # Display image
                image = Image.open(io.BytesIO(response.content))
                image.show()
                print("✓ Image displayed")
            
            return True
        
        except requests.exceptions.Timeout:
            print("✗ Error: Request timeout (generation took too long)")
            return False
        except requests.exceptions.RequestException as e:
            print(f"✗ Error: {e}")
            return False
        except Exception as e:
            print(f"✗ Unexpected error: {e}")
            return False
    
    def generate_image_json(
        self,
        prompt: str,
        negative_prompt: str = "",
        num_inference_steps: int = 50,
        guidance_scale: float = 7.5
    ) -> dict:
        """
        Generate an image and return JSON with S3 URL
        """
        try:
            print(f"📝 Generating image (with S3 upload): {prompt}")
            
            response = requests.post(
                f"{self.api_url}/generate-json",
                files={
                    "prompt": (None, prompt),
                    "negative_prompt": (None, negative_prompt),
                    "num_inference_steps": (None, str(num_inference_steps)),
                    "guidance_scale": (None, str(guidance_scale)),
                },
                timeout=self.timeout
            )
            response.raise_for_status()
            
            result = response.json()
            if result.get("status") == "success":
                print(f"✓ Image ID: {result.get('image_id')}")
                print(f"✓ S3 URL: {result.get('s3_url')}")
            else:
                print(f"✗ Error: {result.get('message', 'Unknown error')}")
            
            return result
        
        except requests.exceptions.RequestException as e:
            print(f"✗ Error: {e}")
            return {"status": "error", "message": str(e)}

def main():
    parser = argparse.ArgumentParser(
        description="Stable Diffusion EC2 API Client",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Health check
  python3 client.py --url http://54.123.45.67:8000 --health
  
  # Generate image and save
  python3 client.py --url http://54.123.45.67:8000 \\
    --prompt "a beautiful sunset over mountains" \\
    --output sunset.png
  
  # Generate with custom parameters
  python3 client.py --url http://54.123.45.67:8000 \\
    --prompt "a cat wearing glasses" \\
    --negative-prompt "blurry, low quality" \\
    --steps 30 \\
    --guidance 7.5 \\
    --output cat.png
  
  # Generate with S3 upload
  python3 client.py --url http://54.123.45.67:8000 \\
    --prompt "a futuristic city" \\
    --s3
        """
    )
    
    parser.add_argument(
        "--url",
        required=True,
        help="API endpoint URL (e.g., http://54.123.45.67:8000)"
    )
    
    parser.add_argument(
        "--health",
        action="store_true",
        help="Check API health status"
    )
    
    parser.add_argument(
        "--prompt",
        type=str,
        help="Image generation prompt"
    )
    
    parser.add_argument(
        "--negative-prompt",
        type=str,
        default="",
        help="Negative prompt to avoid"
    )
    
    parser.add_argument(
        "--steps",
        type=int,
        default=50,
        help="Number of inference steps (default: 50)"
    )
    
    parser.add_argument(
        "--guidance",
        type=float,
        default=7.5,
        help="Guidance scale (default: 7.5)"
    )
    
    parser.add_argument(
        "--output",
        type=str,
        help="Output file path (e.g., output.png)"
    )
    
    parser.add_argument(
        "--s3",
        action="store_true",
        help="Upload result to S3 instead of returning file"
    )
    
    parser.add_argument(
        "--timeout",
        type=int,
        default=300,
        help="Request timeout in seconds (default: 300)"
    )
    
    args = parser.parse_args()
    
    # Validate URL
    if not args.url.startswith("http://") and not args.url.startswith("https://"):
        args.url = "http://" + args.url
    
    client = StableDiffusionClient(args.url, timeout=args.timeout)
    
    # Health check
    if args.health:
        print("🔍 Checking API health...")
        health = client.health_check()
        
        if "error" in health:
            print(f"✗ Error: {health['error']}")
            print(f"✓ Ensure the API is running at: {args.url}")
            sys.exit(1)
        else:
            print("✓ API is healthy!")
            print(f"  Device: {health.get('device', 'unknown')}")
            print(f"  Model: {health.get('model', 'unknown')}")
        
        return
    
    # Generate image
    if args.prompt:
        if args.s3:
            result = client.generate_image_json(
                prompt=args.prompt,
                negative_prompt=args.negative_prompt,
                num_inference_steps=args.steps,
                guidance_scale=args.guidance
            )
            print(json.dumps(result, indent=2))
        else:
            output_file = args.output or "output.png"
            success = client.generate_image(
                prompt=args.prompt,
                negative_prompt=args.negative_prompt,
                num_inference_steps=args.steps,
                guidance_scale=args.guidance,
                output_file=output_file
            )
            sys.exit(0 if success else 1)
    else:
        parser.print_help()
        sys.exit(1)

if __name__ == "__main__":
    main()
