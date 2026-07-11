# Ensure .gitignore is correct
Set-Content -Path .gitignore -Value "cache/`nout/`nbroadcast/`nnode_modules/`n.env`n.env.local`n*.keystore`n"

git add .
git commit -m "Initial commit: Veritas on Ritual Testnet"

# Check gh auth status
gh auth status

# Create repo and push
gh repo create veritas-ritual --public --source=. --remote=origin --push

# Deploy to Vercel
cd frontend
vercel --prod --yes
