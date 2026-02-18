'use client'

import { signIn, useSession } from 'next-auth/react'
import { useRouter } from 'next/navigation'
import { useEffect } from 'react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Icons } from '@/components/ui/icons'

export default function LoginPage() {
  const { data: session, status } = useSession()
  const router = useRouter()

  useEffect(() => {
    if (session) router.push('/dashboard')
  }, [session, router])

  if (status === 'loading') {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Icons.spinner className="h-8 w-8 animate-spin text-primary" />
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 flex items-center justify-center p-4">
      {/* Background decoration */}
      <div className="absolute inset-0 overflow-hidden">
        <div className="absolute -top-40 -right-40 w-80 h-80 rounded-full bg-[#06C167]/10 blur-3xl" />
        <div className="absolute -bottom-40 -left-40 w-80 h-80 rounded-full bg-primary/10 blur-3xl" />
      </div>

      <div className="relative w-full max-w-md">
        {/* Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-[#06C167] flex items-center justify-center text-white font-bold text-lg">M</div>
            <span className="text-white font-bold text-2xl">Mangkok Avenue</span>
          </div>
          <p className="text-slate-400 text-sm">Square ↔ Uber Eats Integration</p>
        </div>

        <Card className="border-slate-700 bg-slate-800/80 backdrop-blur-sm shadow-2xl">
          <CardHeader className="space-y-1 pb-4">
            <CardTitle className="text-2xl text-white text-center">Welcome back</CardTitle>
            <CardDescription className="text-slate-400 text-center">
              Sign in to manage your menu sync
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <Button
              variant="outline"
              className="w-full bg-white hover:bg-gray-50 text-gray-900 border-gray-300 font-medium h-11"
              onClick={() => signIn('google', { callbackUrl: '/dashboard' })}
            >
              <Icons.google className="mr-2 h-5 w-5" />
              Continue with Google
            </Button>

            <Button
              variant="outline"
              className="w-full bg-slate-900 hover:bg-slate-950 text-white border-slate-700 font-medium h-11"
              onClick={() => signIn('github', { callbackUrl: '/dashboard' })}
            >
              <Icons.gitHub className="mr-2 h-5 w-5" />
              Continue with GitHub
            </Button>

            <Button
              variant="outline"
              className="w-full bg-[#2F2F2F] hover:bg-[#1a1a1a] text-white border-slate-700 font-medium h-11"
              onClick={() => signIn('azure-ad', { callbackUrl: '/dashboard' })}
            >
              <Icons.microsoft className="mr-2 h-5 w-5" />
              Continue with Microsoft
            </Button>

            <div className="relative py-2">
              <div className="absolute inset-0 flex items-center">
                <span className="w-full border-t border-slate-700" />
              </div>
              <div className="relative flex justify-center text-xs uppercase">
                <span className="bg-slate-800 px-2 text-slate-500">Or</span>
              </div>
            </div>

            <Button
              variant="outline"
              className="w-full bg-slate-700 hover:bg-slate-600 text-white border-slate-600 font-medium h-11"
              onClick={() => signIn('email', { callbackUrl: '/dashboard' })}
            >
              <Icons.mail className="mr-2 h-5 w-5" />
              Continue with Email
            </Button>

            <p className="text-center text-xs text-slate-500 pt-2">
              Access restricted to authorised team members only.
            </p>
          </CardContent>
        </Card>

        <p className="text-center text-xs text-slate-600 mt-6">
          Mangkok Avenue © {new Date().getFullYear()} · app.mangkokavenue.com
        </p>
      </div>
    </div>
  )
}
