c################ 2011 Kaneshita ################

c#########################################################
c#### hamiltoniank:
c#########################################################

      subroutine diagH(eig,zpsi,dk1,dk2,dk3,ispin)

      use common, only : Nkx, Nky, Nkz, Nband, Nqx, Nqy, Nqz, Check
      implicit none

      integer, intent(in) :: ispin
      real*8, intent(in) :: dk1, dk2, dk3
      real*8, intent(out) :: eig(Nband*Nqx)
      complex*16, intent(out) :: zpsi(Nband*Nqx,Nband*Nqx)

      integer :: i, j, nm
      integer :: info, lwork
      real*8 :: ene(Nband*Nqx)
      real*8 :: rwork(3*Nband*Nqx-2)
      complex*16 :: zdummy
      complex*16 :: work((Nband*Nqx+1)*Nband*Nqx)

      complex*16 :: zhmat(Nband*Nqx,Nband*Nqx)

      !** ispin = ispnとしなかったことで intent(in)であるはずのispinがmakeH_int
      !の中で変更されてしまっているためにコンパイルエラーが起きる可能性がある。
      if ((ispin /= 1).and.(ispin /=2)) then
         write(*,*) 'Error in hamiltonian  -- invalid spin'
         stop
      end if

      nm = Nband * Nqx
      lwork = (nm + 1) * nm

      call makeH(zhmat,dk1,dk2,dk3,ispin)

c## HERMITIAN CHECK[

      if (Check == 'y') then
         call checkHermitian(nm,zhmat,info)
         if(info < 0) stop
         if (info == 1) write(*,*)'Hamiltonian is real',dk1,dk2,dk3
      end if

c## HERMITIAN CHECK]


c## DIAGONALIZATION[

      Info = 0
      call zheev('V','U',nm,zhmat(1:nm,1:nm),nm,ene(1:nm),
     &     work,lwork,rwork,info)
      if(Info /= 0) then
         write(*,*) 'Lapack ZHEEV: Info=',Info
         stop
      end if

      eig(1:nm) = ene(1:nm)
      zpsi(1:nm,1:nm) = zhmat(1:nm,1:nm)

c## DIAGONALIZATION]

      return
      End

c################################################################


c#########################################################
c#### makeH:
c#########################################################

      subroutine makeH(zhmat,dk1,dk2,dk3,ispin)

      use common, only : Nkx, Nky, Nkz, Nband, Nsite, Nqx, Nqy, Nqz,
     &     Pi, Zi, t, Eorbit, Isitex, Isitey, Isitez
      implicit none

      integer, intent(in) :: ispin
      real*8, intent(in) :: dk1, dk2, dk3
      complex*16, intent(out) :: zhmat(Nband*Nqx,Nband*Nqx)

      integer :: is, mu, nu
      integer :: iQ, lQ1
      real*8 :: ak1, ak2, ak3
      complex*16 :: zbloch(0:Nqx,Nsite)

      if ((ispin /= 1).and.(ispin /=2)) then
         write(*,*) 'Error in makeH  -- invalid spin'
         stop
      end if

c######################################################################
c     interaction.pdf: Eq. (12)
c       h_0 + epsilon_mu * delta_(mu,nu)
c       dkx,dky(=akx,aky) <-> k
c       ix,iy   <-> delta_x, delta_y
c######################################################################

      zhmat(:,:) = 0.0d0

      do iQ = 0, Nqx-1
         ak1 = dk1 + DBLE(iQ) / DBLE(Nqx)
         ak2 = dk2 + DBLE(iQ) / DBLE(Nqy)
         ak3 = dk3 + DBLE(iQ) / DBLE(Nqz)
         call calcBlochFactor(zbloch(iQ,:),ak1,ak2,ak3)
      end do

      do is = 1, Nsite
            do mu = 1,Nband ; do nu = 1,Nband
               do iQ = 0, Nqx-1
                  lQ1 = Nband * iQ
                  zhmat(mu+lQ1,nu+lQ1) =  zhmat(mu+lQ1,nu+lQ1)
     &                 + t(is,mu,nu) * zbloch(iQ,is)
               end do
         end do ; end do
      end do

c      call makeH_int(zhmat,ispin,Nband,Nqx)

      return

      End

c################################################################

c#########################################################
c#### bloch: calculate bloch factor at specific k-point
c#########################################################

      subroutine calcBlochFactor(zbloch,dk1,dk2,dk3)

      use common, only: Nkx, Nky, Nsite, Isitex, Isitey, Isitez,
     &      Pi, Zi
      implicit none

      integer :: is, ix, iy, iz
      real*8, intent(in) :: dk1, dk2, dk3
      complex*16, intent(out) :: zbloch(Nsite)

      zbloch(:) = 0.0d0

      do is = 1, Nsite
         ix = isitex(is)
         iy = isitey(is)
         iz = isitez(is)
         zbloch(is) = EXP( 2*Pi*Zi*(ix*dk1+iy*dk2+iz*dk3) )
      end do

      return
      end

c################################################################

c#########################################################
c#### checkHermitian:
c#########################################################

      subroutine checkHermitian(nm,zhmat,info)

      implicit none

      integer, intent(out) :: info
      integer, intent(in) :: nm
      complex*16, intent(in) :: zhmat(nm,nm)

      integer :: i, j, idummy
      complex*16 :: zdummy

      info = 0
c## HERMITIAN CHECK[
      idummy = 0
      do i = 1, nm
         do j = i, nm
            if(AIMAG(zhmat(i,j)) /= 0) then
               idummy = 1
            end if
            zdummy = zhmat(i,j) - CONJG(zhmat(j,i))
            if(ABS(zdummy) > 0.1d-6)then
               write(*,*) 'ERROR -- H IS NOT HERMITIAN'
               write(*,*) i, j, zdummy
               write(*,*) zhmat(i,j), zhmat(j,i)
               write(*,*) '***'
               info = -1        ! Hamiltonian is not hermit
            end if
         end do
      end do
      if (idummy == 0) then
         info = 1               ! Hamiltonian is real
      end if
c## HERMITIAN CHECK]

      return
      End

c################################################################
