import { useState, useEffect } from 'react'
import { createPublicClient, http } from 'viem'
import { VERITAS_CORE_ABI, VERITAS_CORE_ADDRESS, CHAIN_ID, RITUAL_RPC } from './contracts'
import { Shield, ShieldAlert, ShieldCheck, Activity, Search } from 'lucide-react'
import { motion, AnimatePresence } from 'framer-motion'

declare global {
  interface Window {
    ethereum?: any;
  }
}

// Create public client connecting directly to Ritual RPC
const publicClient = createPublicClient({
  transport: http(RITUAL_RPC)
})

export default function App() {
  const [account, setAccount] = useState<string | null>(null)
  const [mediaHash, setMediaHash] = useState('')
  const [mediaUri, setMediaUri] = useState('')
  const [loading, setLoading] = useState(false)
  const [searchHash, setSearchHash] = useState('')
  const [searchResult, setSearchResult] = useState<any>(null)
  
  const showcases = [
    { hash: "0x1234...", uri: "ipfs://Qm...", verdict: 0, score: 890 },
    { hash: "0x8fa9...", uri: "ipfs://Qx...", verdict: 0, score: 950 },
    { hash: "0x5678...", uri: "ipfs://Qc...", verdict: 2, score: 120 },
    { hash: "0x3b4c...", uri: "ipfs://Qp...", verdict: 1, score: 450 },
    { hash: "0x9a2f...", uri: "ipfs://Qz...", verdict: 0, score: 920 },
    { hash: "0x7d8e...", uri: "ipfs://Qw...", verdict: 2, score: 50 },
    { hash: "0x1122...", uri: "ipfs://Qa...", verdict: 0, score: 880 }
  ]

  useEffect(() => {
    // Setup metamask listeners if available
    if (window.ethereum) {
      window.ethereum.on('accountsChanged', (accounts: string[]) => {
        setAccount(accounts[0] || null)
      })
      window.ethereum.on('chainChanged', () => {
        window.location.reload()
      })
    }
  }, [])

  const connectWallet = async () => {
    if (!window.ethereum) return alert('MetaMask not found')
    try {
      const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' })
      setAccount(accounts[0])
      
      // Switch chain
      await window.ethereum.request({
        method: 'wallet_addEthereumChain',
        params: [{
          chainId: `0x${CHAIN_ID.toString(16)}`,
          chainName: 'Ritual Testnet',
          nativeCurrency: { name: 'RITUAL', symbol: 'RITUAL', decimals: 18 },
          rpcUrls: [RITUAL_RPC],
          blockExplorerUrls: ['https://explorer.ritualfoundation.org']
        }]
      })
    } catch (e) {
      console.error(e)
    }
  }

  const generateRandom = () => {
    const randomHash = "0x" + [...Array(64)].map(() => Math.floor(Math.random() * 16).toString(16)).join('')
    setMediaHash(randomHash)
    setMediaUri("ipfs://demo-" + Math.floor(Math.random() * 10000))
  }

  const searchRecord = async () => {
    if (!searchHash) return
    setLoading(true)
    try {
      if (!VERITAS_CORE_ADDRESS.startsWith('0x') || VERITAS_CORE_ADDRESS.length !== 42) {
        // Mock if not deployed
        setSearchResult({
          verdict: Math.floor(Math.random() * 3),
          score: Math.floor(Math.random() * 1000),
          reasoning: "Mock read from Ritual testnet."
        })
      } else {
        const data = await publicClient.readContract({
          address: VERITAS_CORE_ADDRESS as `0x${string}`,
          abi: VERITAS_CORE_ABI,
          functionName: 'records',
          args: [searchHash as `0x${string}`]
        }) as any
        setSearchResult({
          verdict: data[4],
          score: Number(data[3]),
          reasoning: data[7]
        })
      }
    } catch (e) {
      console.error(e)
    }
    setLoading(false)
  }

  return (
    <div className="min-h-screen p-8 max-w-5xl mx-auto flex flex-col gap-12">
      <header className="flex justify-between items-center">
        <div className="flex items-center gap-3">
          <Shield className="w-8 h-8 text-[#9048f7]" />
          <h1 className="text-3xl font-bold tracking-tight">Veritas</h1>
        </div>
        <button 
          onClick={connectWallet}
          className="px-6 py-2 rounded-full font-medium transition-transform active:scale-95 glass-panel hover:bg-white/10"
        >
          {account ? `${account.slice(0,6)}...${account.slice(-4)}` : 'Connect Wallet'}
        </button>
      </header>

      <main className="grid md:grid-cols-2 gap-8">
        <div className="glass-panel p-8 flex flex-col gap-6 relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-32 bg-[#9048f7] rounded-full blur-[100px] opacity-10 group-hover:opacity-20 transition-opacity"></div>
          <h2 className="text-2xl font-semibold z-10">Verify Media</h2>
          <p className="text-white/60 z-10">Submit media hash and URI to analyze authenticity via Ritual TEE.</p>
          
          <div className="flex flex-col gap-4 z-10">
            <input 
              value={mediaHash}
              onChange={e => setMediaHash(e.target.value)}
              placeholder="Media Hash (0x...)" 
              className="bg-black/30 border border-white/10 rounded-lg px-4 py-3 outline-none focus:border-[#9048f7] transition-colors"
            />
            <input 
              value={mediaUri}
              onChange={e => setMediaUri(e.target.value)}
              placeholder="Media URI (ipfs://...)" 
              className="bg-black/30 border border-white/10 rounded-lg px-4 py-3 outline-none focus:border-[#9048f7] transition-colors"
            />
            <div className="flex gap-4">
              <button 
                className="flex-1 bg-[#9048f7] text-white py-3 rounded-lg font-medium active:scale-95 transition-transform"
                onClick={() => alert("Verification submission triggered (Requires smart contract write)")}
              >
                Submit to Agent
              </button>
              <button 
                onClick={generateRandom}
                className="px-4 py-3 bg-white/5 border border-white/10 rounded-lg active:scale-95 transition-transform"
              >
                Random
              </button>
            </div>
          </div>
        </div>

        <div className="glass-panel p-8 flex flex-col gap-6">
          <h2 className="text-2xl font-semibold">Lookup Certificate</h2>
          <div className="flex gap-4">
            <input 
              value={searchHash}
              onChange={e => setSearchHash(e.target.value)}
              placeholder="Media Hash" 
              className="flex-1 bg-black/30 border border-white/10 rounded-lg px-4 py-3 outline-none focus:border-white/30 transition-colors"
            />
            <button 
              onClick={searchRecord}
              className="px-4 bg-white/10 border border-white/10 rounded-lg hover:bg-white/20 transition-colors active:scale-95"
            >
              <Search className="w-5 h-5" />
            </button>
          </div>

          <AnimatePresence>
            {loading && (
              <motion.div initial={{opacity:0}} animate={{opacity:1}} exit={{opacity:0}} className="flex items-center gap-2 text-white/50">
                <Activity className="w-4 h-4 animate-spin" /> Fetching from Ritual...
              </motion.div>
            )}
            {searchResult && (
              <motion.div 
                initial={{opacity: 0, y: 10}}
                animate={{opacity: 1, y: 0}}
                className={`p-6 rounded-xl border ${
                  searchResult.verdict === 0 ? 'bg-[#10b981]/10 border-[#10b981]/30' : 
                  searchResult.verdict === 1 ? 'bg-[#f59e0b]/10 border-[#f59e0b]/30' : 
                  'bg-[#ef4444]/10 border-[#ef4444]/30'
                }`}
              >
                <div className="flex items-center gap-3 mb-2">
                  {searchResult.verdict === 0 ? <ShieldCheck className="text-[#10b981]" /> : <ShieldAlert className="text-[#ef4444]" />}
                  <span className="font-semibold text-lg">
                    {searchResult.verdict === 0 ? 'Authentic' : searchResult.verdict === 1 ? 'Suspicious' : 'Likely Deepfake'}
                  </span>
                </div>
                <div className="text-sm opacity-80 mb-4">Score: {searchResult.score}/1000</div>
                <div className="text-sm opacity-60">AI Reasoning: {searchResult.reasoning}</div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>
      </main>

      <section>
        <h3 className="text-xl font-medium mb-6">Recent Verifications</h3>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {showcases.map((s, i) => (
            <div key={i} className="glass-panel p-4 flex flex-col gap-2 opacity-60 hover:opacity-100 transition-opacity">
              <div className="text-xs font-mono">{s.hash}</div>
              <div className="flex justify-between items-center mt-auto pt-4">
                <span className={`text-xs px-2 py-1 rounded ${s.verdict === 0 ? 'bg-[#10b981]/20 text-[#10b981]' : s.verdict === 1 ? 'bg-[#f59e0b]/20 text-[#f59e0b]' : 'bg-[#ef4444]/20 text-[#ef4444]'}`}>
                  {s.verdict === 0 ? 'Authentic' : s.verdict === 1 ? 'Suspicious' : 'Deepfake'}
                </span>
                <span className="text-xs">{s.score}</span>
              </div>
            </div>
          ))}
          <div className="glass-panel p-4 flex items-center justify-center opacity-40 hover:opacity-80 transition-opacity cursor-pointer">
            <span className="text-2xl font-bold tracking-[0.2em] text-white/50">...</span>
          </div>
        </div>
      </section>
    </div>
  )
}
