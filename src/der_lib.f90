 !*****************************************************************************************************!
 !             Copyright 2008-2016 Pasquale Londrillo, Stefano Sinigardi, Andrea Sgattoni              !
 !*****************************************************************************************************!

 !*****************************************************************************************************!
 !  This file is part of ALaDyn.                                                                       !
 !                                                                                                     !
 !  ALaDyn is free software: you can redistribute it and/or modify                                     !
 !  it under the terms of the GNU General Public License as published by                               !
 !  the Free Software Foundation, either version 3 of the License, or                                  !
 !  (at your option) any later version.                                                                !
 !                                                                                                     !
 !  ALaDyn is distributed in the hope that it will be useful,                                          !
 !  but WITHOUT ANY WARRANTY; without even the implied warranty of                                     !
 !  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                                      !
 !  GNU General Public License for more details.                                                       !
 !                                                                                                     !
 !  You should have received a copy of the GNU General Public License                                  !
 !  along with ALaDyn.  If not, see <http://www.gnu.org/licenses/>.                                    !
 !*****************************************************************************************************!

 module der_lib

 use precision_def
 use util

 implicit none

 real(dp),allocatable :: dw(:),zp(:),amat(:,:),rmat(:,:)
 real(dp),allocatable :: mat_der_inv(:,:),fmat(:,:,:),lpl_mat(:,:,:)
 real(dp),allocatable :: mat_env(:,:)
 real(dp) :: aph_der,avg_cmp,cmp_coeff(2),se_coeff(2), se4_coeff(2),&
  filt_coeff(0:6),falp,int_coeff(0:3)
 logical :: derinv
 contains
 !==========================================
 subroutine set_mat_der(nu,n1,n2,n3,nd,ib1,ord,filt,fform)

 real(dp),intent(in) :: nu
 integer,intent(in) :: n1,n2,n3,nd,ib1,ord,filt,fform
 integer :: nd_max
 real(dp) :: aph
 !------------------ Compact derivarives coefficients
 derinv=.false.
 avg_cmp=0.0
 !---------------
 select case(ord)
 case(2)
  cmp_coeff(1)=1.
  cmp_coeff(2)=0.
  avg_cmp=1.0
  aph_der=cmp_coeff(2)*avg_cmp
  !OSE4 optimized explicit nu=cfl in 1D
  !                        nu=cfl*rat/sqrt(1.+rat*rat) multi-D
 case(3)
  cmp_coeff(1)=1.+0.125*(1.-1.2*nu*nu)  !Modified along x-coord
  cmp_coeff(2)=(1.-cmp_coeff(1))/3.
  avg_cmp=1./(cmp_coeff(1)+cmp_coeff(2))
  aph_der=cmp_coeff(2)*avg_cmp
  derinv=.true.
 case(4)
  cmp_coeff(1)=1.125   !9/8(SE4)
  cmp_coeff(2)=(1.-cmp_coeff(1))/3.  !-1./24
  avg_cmp=1./(cmp_coeff(1)+cmp_coeff(2))
  aph_der=cmp_coeff(2)*avg_cmp
  derinv=.true.
  se4_coeff(1)=4./3.
  se4_coeff(2)=-1./6.
  !------------------------------
 end select
 se_coeff(1:2)=cmp_coeff(1:2)
 !----------------------------------
 nd_max=max(n1,n2,n3)
 allocate(dw(0:nd_max+1),zp(nd_max))
 dw=0.0
 !++++++++++++++++++++++++++++
 if(derinv)then
  allocate(mat_der_inv(nd_max,3))
  mat_der_inv=0.0
 endif
 if(fform >1)then
  allocate(lpl_mat(nd_max,3,nd))
  if(n1 >1)call set_lpl_mat(n1,1)
  if(n2 >1)call set_lpl_mat(n2,2)
  if(n3 >1)call set_lpl_mat(n3,3)
 endif

 if(filt >0)then
  allocate(fmat(nd_max,3,nd))
  fmat=0.0
  aph=0.475                      !Lele  tridiag C.2.4
  filt_coeff(0)=aph
  filt_coeff(1)=(6.*aph+5.)/8.   !a
  filt_coeff(2)=0.25*(2.*aph+1.) !b/2
  filt_coeff(3)=(2.*aph-1.)/16.  !c/2
 endif
 !++++++++++++++++++++++++++++
 select case(ib1)
 case(0)
  if(derinv)call set_der_inv(n1,aph_der,aph_der,ib1)
 case(1)
  if(derinv)call set_der_inv(n1-1,aph_der,aph_der,ib1)
 end select
 end subroutine set_mat_der
 !=============================
 subroutine trid_lpl_inv(n,dir)
 integer,intent(in) :: n,dir
 integer :: ix
 ix=1
 dw(ix)=lpl_mat(ix,2,dir)*dw(ix)
 do ix=2,n
  dw(ix)=dw(ix)-lpl_mat(ix,1,dir)*dw(ix-1)
  dw(ix)=lpl_mat(ix,2,dir)*dw(ix)
 end do
 do ix=n-1,1,-1
  dw(ix)=dw(ix)-lpl_mat(ix,3,dir)*dw(ix+1)
 end do
 end subroutine trid_lpl_inv
 !=========================
 subroutine trid_der_inv(n,ib)
 integer,intent(in) :: n,ib
 integer :: ix
 real(dp) :: alp0,bet0,gm,fact

 ix=1
 dw(ix)=mat_der_inv(ix,2)*dw(ix)
 do ix=2,n
  dw(ix)=dw(ix)-mat_der_inv(ix,1)*dw(ix-1)
  dw(ix)=mat_der_inv(ix,2)*dw(ix)
 end do
 do ix=n-1,1,-1
  dw(ix)=dw(ix)-mat_der_inv(ix,3)*dw(ix+1)
 end do
 if(ib/=1)return
 alp0=mat_der_inv(n,3)
 bet0=mat_der_inv(1,1)
 gm=-1.0
 zp(2:n-1)=0.0
 zp(1)=gm
 zp(n)=alp0
 !-----------call trid of z
 zp(1)=mat_der_inv(1,2)*zp(1)
 do ix=2,n
  zp(ix)=zp(ix)-mat_der_inv(ix,1)*zp(ix-1)
  zp(ix)=mat_der_inv(ix,2)*zp(ix)
 end do
 do ix=n-1,1,-1
  zp(ix)=zp(ix)-mat_der_inv(ix,3)*zp(ix+1)
 end do
 fact=(dw(1)+bet0*dw(n)/gm)/(1.0+zp(1)+bet0*zp(n)/gm)
 dw(1:n)=dw(1:n)-fact*zp(1:n)
 dw(n+1)=dw(1)
 !=======================
 end subroutine trid_der_inv
 !============================
 subroutine ftrid(n,ib,dir)
 integer,intent(in) :: n,ib,dir
 integer :: ix
 real(dp) :: alp0,bet0,gm,fact
 ix=1
 dw(ix)=fmat(ix,2,dir)*dw(ix)
 do ix=2,n
  dw(ix)=dw(ix)-fmat(ix,1,dir)*dw(ix-1)
  dw(ix)=fmat(ix,2,dir)*dw(ix)
 end do
 do ix=n-1,1,-1
  dw(ix)=dw(ix)-fmat(ix,3,dir)*dw(ix+1)
 end do
 if(ib/=1)return
 alp0=fmat(n,3,dir)
 bet0=fmat(1,1,dir)
 gm=-1.0
 zp(2:n-1)=0.0
 zp(1)=gm
 zp(n)=alp0
 !-----------call trid of z
 zp(1)=fmat(1,2,dir)*zp(1)
 do ix=2,n
  zp(ix)=zp(ix)-fmat(ix,1,dir)*zp(ix-1)
  zp(ix)=fmat(ix,2,dir)*zp(ix)
 end do
 do ix=n-1,1,-1
  zp(ix)=zp(ix)-fmat(ix,3,dir)*zp(ix+1)
 end do
 fact=(dw(1)+bet0*dw(n)/gm)/(1.0+zp(1)+bet0*zp(n)/gm)
 dw(1:n)=dw(1:n)-fact*zp(1:n)
 dw(n+1)=dw(1)
 end subroutine ftrid
 !=======================
 subroutine set_lpl_mat(ng1,dir)
 integer,intent(in) :: ng1,dir
 integer :: i

 lpl_mat(1:ng1,1,dir)=1.0
 lpl_mat(1:ng1,2,dir)=-2.0
 lpl_mat(1:ng1,3,dir)=1.0
 !        LU Factorize
 lpl_mat(1,2,dir)=1.0/lpl_mat(1,2,dir)
 do i=2,ng1
  lpl_mat(i-1,3,dir)=lpl_mat(i-1,3,dir)*lpl_mat(i-1,2,dir)
  lpl_mat(i,2,dir)=lpl_mat(i,2,dir)- &
   lpl_mat(i-1,3,dir)*lpl_mat(i,1,dir)
  lpl_mat(i,2,dir)=1.0/lpl_mat(i,2,dir)
 end do
 end subroutine set_lpl_mat
 !===================
 !=======================
 subroutine set_radlpl_mat(rhg,rg,ng1)
 real(dp),intent(in) :: rhg(:),rg(:)
 integer,intent(in) :: ng1
 integer :: i

 allocate(rmat(ng1,3))

 i=1
 rmat(i,1)=0.0
 rmat(i,2)=-2.0
 rmat(i,3)= 2.0
 do i=2,ng1-1
  rmat(i,1)=rhg(i-1)/rg(i)
  rmat(i,2)=-(rhg(i-1)+rhg(i))/rg(i)
  rmat(i,3)=rhg(i)/rg(i)
 end do
 i=ng1     !pot(ng1+1)=0
 rmat(i,1)=rhg(i-1)/rg(i)
 rmat(i,2)=-(rhg(i-1)+rhg(i))/rg(i)
 !rmat(i,1)=-(rh(ng1)-rh(ng1-1))  linear extrapolation
 !rmat(i,2)=(rh(ng1)-rh(ng1-1))
 !        LU Factorize
 rmat(1,2)=1.0/rmat(2,2)
 do i=2,ng1
  rmat(i-1,3)=rmat(i-1,3)*rmat(i-1,2)
  rmat(i,2)=rmat(i,2)- &
   rmat(i-1,3)*rmat(i,1)
  rmat(i,2)=1.0/rmat(i,2)
 end do
 end subroutine set_radlpl_mat
 !===================
 !----------------------------------------------
 !----------------------------------------------
 !===============================================
 subroutine set_der_inv(ng,aph,aph1,ib)
 integer,intent(in) :: ng,ib
 real(dp),intent(in) :: aph,aph1
 integer :: i
 real(dp) :: ap,gm,bt

 mat_der_inv(1:ng,1)=aph
 mat_der_inv(1:ng,2)=1.0
 mat_der_inv(1:ng,3)=aph
 select case(ib)
 case(0)
  mat_der_inv(1,1)=0.0
  mat_der_inv(1,3)=0.0
  mat_der_inv(2,1)=aph1
  mat_der_inv(2,3)=aph1
  mat_der_inv(ng-1,1)=aph1
  mat_der_inv(ng-1,3)=aph1
  mat_der_inv(ng,3)=0.0
  mat_der_inv(ng,1)=0.0
 case(1)
  !   the cyclic matrix
  ap=mat_der_inv(ng,3)
  bt=mat_der_inv(1,1)
  gm=-mat_der_inv(1,2)
  mat_der_inv(1,2)=mat_der_inv(1,2)-gm
  mat_der_inv(ng,2)=mat_der_inv(ng,2)-ap*bt/gm
 end select
 !        LU Factorize
 mat_der_inv(1,2)=1.0/mat_der_inv(1,2)
 do i=2,ng
  mat_der_inv(i-1,3)=mat_der_inv(i-1,3)*mat_der_inv(i-1,2)
  mat_der_inv(i,2)=mat_der_inv(i,2)- &
   mat_der_inv(i-1,3)*mat_der_inv(i,1)
  mat_der_inv(i,2)=1.0/mat_der_inv(i,2)
 end do

 end subroutine set_der_inv
 subroutine penta_diag_lufact(ng)

 integer,intent(in) :: ng
 integer :: i
 mat_env(1,3)=1.0/mat_env(1,3)
 do i=2,ng-1
  if(i==3)mat_env(i-1,4)=mat_env(i-1,4)-mat_env(i-1,2)*mat_env(i-2,5)
  !A(i-1,i)=A(i-1,i)-A(i-1,i-2)*A(i-2,i)
  mat_env(i-1,4)=mat_env(i-1,4)*mat_env(i-1,3)
  !A(i-1,i)=A(i-1,i-1)*A(i-1,i)
  mat_env(i,3)=mat_env(i,3)- &
   mat_env(i-1,4)*mat_env(i,2)
  !A(i,i)=A(i,i)-A(i,i-1)*A(i-1,i)
  mat_env(i,3)=1.0/mat_env(i,3)
 end do
 i=ng
 mat_env(i,2)=mat_env(i,2)- &
  mat_env(i,1)*mat_env(i-2,4)
 !A(i,i-1)=A(i,i-1)-A(i,i-2)*A(i-2,i-1)
 mat_env(i,3)=mat_env(i,3)- &
  mat_env(i-1,4)*mat_env(i,2)
 !A(i,i)=A(i,i)-A(i,i-1)*A(i-1,i)
 mat_env(i,3)=1.0/mat_env(i,3)
 end subroutine penta_diag_lufact
 !==============================
 subroutine set_mat_env5(om0,aph,ap,dg_inv,ng)
 integer,intent(in) :: ng
 real(dp),intent(in) ::om0,aph,ap,dg_inv
 integer :: i,j
 real(dp) :: ap2,alp2,om2,dx2
 real(dp) :: a,b,d
 !==============
 !==============
 amat=0.0
 alp2=aph*aph
 ap2=ap*ap
 om2=om0*om0
 dx2=dg_inv*dg_inv


 a=alp2+ap2*dx2/om2
 b=2.*aph
 d=2.*alp2+1.-2.*ap2*dx2/om2

 !  Symmetric BC's

 amat(1,1)=d
 amat(1,2)=2.*b
 amat(1,3)=2.*a
 amat(2,1)=b
 amat(2,2)=d+a
 amat(2,3)=b
 amat(2,4)=a
 do j=3,ng-2
  amat(j,j-2)=a
  amat(j,j-1)=b
  amat(j,j)=d
  amat(j,j+1)=b
  amat(j,j+2)=a
 end do
 amat(ng-1,ng-3)=a
 amat(ng-1,ng-2)=b
 amat(ng-1,ng-1)=d+a
 amat(ng-1,ng)=b
 amat(ng,ng-2)=2.*a
 amat(ng,ng-1)=2.*b
 amat(ng,ng)=d
 !        LU Factorize a penta-diagonal matrix
 call  ludcmp(amat,ng)
 mat_env(1,1:2)=0.0
 mat_env(1,3:5)=amat(1,1:3)
 mat_env(2,2:5)=amat(2,1:4)
 do j=3,ng-2
  mat_env(j,1:5)=amat(j,j-2:j+2)
 end do
 mat_env(ng-1,1:4)=amat(ng-1,ng-3:ng)
 mat_env(ng,1:3)=amat(ng,ng-2:ng)
 do i=1,5
  do j=1,ng
   if(abs(mat_env(j,i)) <1.e-08)mat_env(j,i)=0.0
  end do
 end do
 end subroutine set_mat_env5
 !=======================
 subroutine set_mat_env2(bp,aph,ng)
 integer,intent(in) :: ng
 real(dp),intent(in) :: bp,aph
 integer :: i
 real(dp) :: ap2,a,b,c,b1,c1,d1,en,an,bn
 !==============
 !==============
 ap2=bp*bp
 b1=1.+ap2*(1.-aph)*(1.-aph)
 c1=2.*ap2*aph*(1.-aph)
 d1=ap2*aph*aph
 !                      first row
 a=ap2*aph*(aph-1.)
 b=1.+ap2*(1.-2.*aph*aph)
 c=ap2*aph*(aph+1.)
 !                    !interior rows
 en=d1
 bn=1.+ap2*(1.+aph)*(1.+aph)
 an=-2.*ap2*aph*(1.+aph)
 !                      last row

 mat_env(1,1:2)=0.0
 mat_env(1,3)=b1
 mat_env(1,4)=c1
 mat_env(1,5)=d1
 mat_env(2:ng-1,2)=a
 mat_env(2:ng-1,3)=b
 mat_env(2:ng-1,4)=c
 mat_env(ng,1)=en
 mat_env(ng,2)=an
 mat_env(ng,3)=bn
 mat_env(ng,4:5)=0.0
 !        LU Factorize a tri-diagonal matrix

 mat_env(1,3)=1.0/mat_env(1,3)
 do i=2,ng-1
  if(i==3)mat_env(i-1,4)=mat_env(i-1,4)-mat_env(i-1,2)*mat_env(i-2,5)
  !A(i-1,i)=A(i-1,i)-A(i-1,i-2)*A(i-2,i)
  mat_env(i-1,4)=mat_env(i-1,4)*mat_env(i-1,3)
  !A(i-1,i)=A(i-1,i-1)*A(i-1,i)
  mat_env(i,3)=mat_env(i,3)- &
   mat_env(i-1,4)*mat_env(i,2)
  !A(i,i)=A(i,i)-A(i,i-1)*A(i-1,i)
  mat_env(i,3)=1.0/mat_env(i,3)
 end do
 i=ng
 mat_env(i,2)=mat_env(i,2)- &
  mat_env(i,1)*mat_env(i-2,4)
 !A(i,i-1)=A(i,i-1)-A(i,i-2)*A(i-2,i-1)
 mat_env(i,3)=mat_env(i,3)- &
  mat_env(i-1,4)*mat_env(i,2)
 !A(i,i)=A(i,i)-A(i,i-1)*A(i-1,i)
 mat_env(i,3)=1.0/mat_env(i,3)
 end subroutine set_mat_env2
 !----------------------------------------------
 end module der_lib
 !===============================================
